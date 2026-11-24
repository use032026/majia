# frozen_string_literal: true

require_relative "asc_review_submission"
require_relative "asc_review_cancellation"

module MajiaCI
  class ASCJufuIsolatedSubmissionError < ASCSubmissionError
    attr_reader :evidence

    def initialize(message, evidence:)
      super(message)
      @evidence = evidence
    end
  end

  module ASCJufuIsolatedSubmission
    module_function

    class ValidationError < StandardError; end

    APP_ID = "6813407162"
    BUNDLE_ID = "com.lunelle.lite"
    MARKETING_VERSION = "1.0.3"
    VERSION_ID = "a8033d7d-27ad-471c-b4f2-c366e90eb181"
    BUILD_ID = "7f7413e2-fcaa-43a8-a1f3-5dbf7ce5f290"
    BUILD_NUMBER = "1"
    EXCLUDED_SUBMISSION_ID = "c13cf1c4-5190-44b2-9457-01185ad0e1c9"
    RESOURCE_ID = /\A[A-Za-z0-9_-]{1,128}\z/
    STATES = %w[READY_FOR_REVIEW WAITING_FOR_REVIEW IN_REVIEW UNRESOLVED_ISSUES CANCELING COMPLETING COMPLETE].freeze
    ACCEPTED_STATES = %w[WAITING_FOR_REVIEW IN_REVIEW COMPLETING COMPLETE].freeze
    BLOCKING_STATES = %w[WAITING_FOR_REVIEW IN_REVIEW UNRESOLVED_ISSUES CANCELING COMPLETING].freeze
    EDITABLE_STATES = %w[PREPARE_FOR_SUBMISSION READY_FOR_REVIEW].freeze
    SUBMITTED_VERSION_STATES = (ASCReviewSubmission::SUBMITTED_VERSION_STATES + ASCReviewSubmission::RELEASED_VERSION_STATES).freeze
    RELATIONS = ASCReviewCancellation::ITEM_RELATIONSHIPS

    # Keep only fixed templates: no IDs, pagination URLs, query values or remote
    # messages are copied into the diagnostic fields.
    class DiagnosticClient
      def initialize(client, summary)
        @client = client
        @summary = summary
      end

      def get(path, query = nil)
        observe(:get, path) { @client.get(path, query) }
      end

      def paginate(path, query = nil, **options)
        observe(:get, path) { @client.paginate(path, query, **options) }
      end

      def post_created(path, payload)
        observe(:post, path) { @client.post_created(path, payload) }
      end

      def patch(path, payload)
        observe(:patch, path) { @client.patch(path, payload) }
      end

      private

      def observe(method, path)
        template = case path
                   when "/v1/apps" then "/v1/apps"
                   when "/v1/apps/#{APP_ID}/appStoreVersions" then "/v1/apps/{fixed_app}/appStoreVersions"
                   when "/v1/appStoreVersions/#{VERSION_ID}/relationships/build" then "/v1/appStoreVersions/{fixed_version}/relationships/build"
                   when "/v1/builds/#{BUILD_ID}" then "/v1/builds/{fixed_build}"
                   when "/v1/apps/#{APP_ID}/reviewSubmissions" then "/v1/apps/{fixed_app}/reviewSubmissions"
                   when %r{\A/v1/reviewSubmissions/[A-Za-z0-9_-]{1,128}/items\z} then "/v1/reviewSubmissions/{submission}/items"
                   when "/v1/reviewSubmissions" then "/v1/reviewSubmissions"
                   when "/v1/reviewSubmissionItems" then "/v1/reviewSubmissionItems"
                   when %r{\A/v1/reviewSubmissions/[A-Za-z0-9_-]{1,128}\z} then "/v1/reviewSubmissions/{submission}"
                   end
        raise ASCSubmissionError, "unrecognized_diagnostic_request_path" unless template

        operation = case template
                    when "/v1/apps/{fixed_app}/reviewSubmissions" then "review_batch_list"
                    when "/v1/reviewSubmissions/{submission}/items" then "review_item_list"
                    else "fixed_scope_request"
                    end
        descriptor = { "method" => method.to_s.upcase, "path_template" => template, "operation" => operation }
        @summary["last_request"] = descriptor
        yield
      rescue StandardError => error
        diagnostic = descriptor || { "method" => method.to_s.upcase, "path_template" => "UNRECOGNIZED" }
        if error.is_a?(ASCStatusError)
          diagnostic = diagnostic.merge("http_status" => error.http_status, "apple_error_codes" => error.api_error_codes)
        end
        @summary["failed_request"] = diagnostic
        raise
      end
    end

    def run(client:, execute: false, checked_at: Time.now.utc, clock: -> { Time.now.utc })
      summary = {
        "schema_version" => 1, "checked_at" => checked_at.utc.iso8601, "execute" => execute == true,
        "app" => { "id" => APP_ID, "bundle_id" => BUNDLE_ID },
        "version" => { "id" => VERSION_ID, "version_string" => MARKETING_VERSION, "platform" => "IOS" },
        "build" => { "id" => BUILD_ID, "version" => BUILD_NUMBER },
        "excluded_submission_id" => EXCLUDED_SUBMISSION_ID,
        "ready_to_submit" => false, "review_submitted" => false, "no_op" => false,
        "phase" => "preflight", "requests" => [], "errors" => [],
        "evidence_boundary" => "One fixed Jufu version only. Existing empty or unrelated review batches are never modified. Does not build, upload, change metadata, release or prove approval."
      }
      check!([true, false].include?(execute), "invalid_execute")
      client = DiagnosticClient.new(client, summary)
      target = read_target!(client)
      summary["before"] = target
      inventory = read_inventory!(client)
      summary["inventory"] = inventory.map { |row| row.reject { |key, _| key == "resource" } }
      candidate = select_candidate!(inventory, target)
      if candidate && ACCEPTED_STATES.include?(candidate.fetch("state"))
        summary.merge!("review_submission" => candidate_receipt(candidate), "review_submitted" => true,
                       "ready_to_submit" => false, "no_op" => true, "phase" => "already_submitted")
        return summary
      end
      check!(EDITABLE_STATES.include?(target.fetch("version_state")), "version_is_not_editable")
      summary["ready_to_submit"] = true
      unless execute
        summary["phase"] = "dry_run_ready"
        summary["review_submission"] = candidate && candidate_receipt(candidate)
        return summary
      end

      ensure_submission_day!(clock)
      unless candidate
        summary["phase"] = "creating_isolated_batch"
        summary["requests"] << { "method" => "POST", "path" => "/v1/reviewSubmissions", "outcome" => "requested" }
        response = client.post_created("/v1/reviewSubmissions", {
          "data" => { "type" => "reviewSubmissions", "attributes" => { "platform" => "IOS" },
                      "relationships" => { "app" => { "data" => { "type" => "apps", "id" => APP_ID } } } }
        }).fetch("data")
        check!(resource?(response, "reviewSubmissions") && response.dig("attributes", "state") == "READY_FOR_REVIEW" &&
               response.dig("attributes", "platform") == "IOS" && scoped?(response) &&
               response["id"] != EXCLUDED_SUBMISSION_ID && inventory.none? { |row| row["id"] == response["id"] },
               "created_batch_identity_unverified")
        id = response.fetch("id")
        summary["created_submission_id"] = id
        summary["requests"].last.merge!("outcome" => "created", "id" => id)
        created_inventory = read_inventory!(client)
        created = created_inventory.select { |row| row["id"] == id }
        check!(created.length == 1 && created.first["state"] == "READY_FOR_REVIEW" && created.first["item_count"].zero? &&
               !created.first["direct_target"], "new_batch_not_verified_empty")
        check_no_blocker!(created_inventory, id)
        summary["phase"] = "adding_only_target_item"
        summary["requests"] << { "method" => "POST", "path" => "/v1/reviewSubmissionItems", "outcome" => "requested", "submission_id" => id }
        item = client.post_created("/v1/reviewSubmissionItems", {
          "data" => { "type" => "reviewSubmissionItems", "relationships" => {
            "reviewSubmission" => { "data" => { "type" => "reviewSubmissions", "id" => id } },
            "appStoreVersion" => { "data" => { "type" => "appStoreVersions", "id" => VERSION_ID } }
          } }
        }).fetch("data")
        check!(resource?(item, "reviewSubmissionItems"), "created_item_identity_unverified")
        summary["created_item_id"] = item.fetch("id")
        summary["requests"].last.merge!("outcome" => "created", "id" => item.fetch("id"))
        candidate = { "id" => id, "state" => "READY_FOR_REVIEW" }
      end

      summary["phase"] = "final_preflight"
      current = read_target!(client)
      check!(EDITABLE_STATES.include?(current.fetch("version_state")), "version_changed_before_submit")
      inventory = read_inventory!(client)
      selected = inventory.select { |row| row["id"] == candidate.fetch("id") }
      check!(selected.length == 1 && selected.first["state"] == "READY_FOR_REVIEW" && selected.first["target_only"], "candidate_not_unique_target_only")
      check_no_blocker!(inventory, candidate.fetch("id"))
      candidate = selected.first
      if summary["created_item_id"]
        check!(candidate["item_id"] == summary["created_item_id"], "created_item_readback_mismatch")
      end
      summary["pre_submit"] = current
      summary["review_submission"] = candidate_receipt(candidate)
      id = candidate.fetch("id")
      check!(id != EXCLUDED_SUBMISSION_ID, "excluded_batch_must_never_change")
      ensure_submission_day!(clock)
      summary["ready_to_submit"] = false
      summary["phase"] = "submitting_isolated_batch"
      summary["requests"] << { "method" => "PATCH", "path" => "/v1/reviewSubmissions/#{id}", "outcome" => "requested" }
      client.patch("/v1/reviewSubmissions/#{id}", {
        "data" => { "type" => "reviewSubmissions", "id" => id, "attributes" => { "submitted" => true } }
      })
      summary["requests"].last["outcome"] = "accepted_response"
      summary["phase"] = "verifying_acceptance"
      after = read_target!(client)
      inventory = read_inventory!(client)
      observed = inventory.select { |row| row["id"] == id }
      check!(observed.length == 1 && observed.first["target_only"] && ACCEPTED_STATES.include?(observed.first["state"]) &&
             SUBMITTED_VERSION_STATES.include?(after["version_state"]), "formal_acceptance_not_confirmed")
      summary.merge!("after" => after, "review_submission" => candidate_receipt(observed.first),
                     "ready_to_submit" => false, "review_submitted" => true, "phase" => "submitted")
      summary
    rescue ASCJufuIsolatedSubmissionError
      raise
    rescue StandardError => error
      code = error.is_a?(ValidationError) ? error.message : "isolated_submission_could_not_be_verified"
      error_class = case error
                    when ValidationError then "ValidationError"
                    when ASCPermissionError then "ASCPermissionError"
                    when ASCStatusError then "ASCStatusError"
                    when KeyError then "KeyError"
                    when TypeError then "TypeError"
                    else "UnverifiedError"
                    end
      summary["ready_to_submit"] = false
      summary["errors"] << { "code" => code, "phase" => summary["phase"],
                             "kind" => error.is_a?(ValidationError) ? "scope_rejected" : "request_failed",
                             "error_class" => error_class }
      raise ASCJufuIsolatedSubmissionError.new("Jufu isolated submission stopped; inspect the saved phase receipt", evidence: summary)
    end

    def ensure_submission_day!(clock)
      instant = clock.call
      check!(instant.is_a?(Time), "submission_clock_unverified")
      check!((instant.getutc + 8 * 60 * 60).wday != 0, "beijing_sunday_submission_blocked")
    end
    private_class_method :ensure_submission_day!

    def check!(condition, code)
      raise ValidationError, code unless condition
    end
    private_class_method :check!

    def resource?(resource, type)
      resource.is_a?(Hash) && resource["type"] == type && resource["id"].is_a?(String) && resource["id"].match?(RESOURCE_ID) && resource["attributes"].is_a?(Hash)
    end
    private_class_method :resource?

    def scoped?(resource)
      relations = resource["relationships"]
      return true if relations.nil?
      return false unless relations.is_a?(Hash)
      return true unless relations.key?("app")

      relation = relations["app"]
      return false unless relation.is_a?(Hash)
      return true unless relation.key?("data")

      relation["data"] == { "type" => "apps", "id" => APP_ID }
    end
    private_class_method :scoped?

    def read_target!(client)
      apps = client.paginate("/v1/apps", { "filter[bundleId]" => BUNDLE_ID, "fields[apps]" => "bundleId", "limit" => "2" })
      check!(apps.is_a?(Array) && apps.length == 1 && resource?(apps.first, "apps") && apps.first["id"] == APP_ID && apps.first.dig("attributes", "bundleId") == BUNDLE_ID,
             "fixed_app_identity_mismatch")
      versions = client.paginate("/v1/apps/#{APP_ID}/appStoreVersions", {
        "filter[platform]" => "IOS", "filter[versionString]" => MARKETING_VERSION,
        "fields[appStoreVersions]" => "platform,versionString,appVersionState,releaseType", "limit" => "200"
      })
      check!(versions.is_a?(Array) && versions.length == 1, "fixed_version_not_unique")
      version = versions.first
      check!(resource?(version, "appStoreVersions") && scoped?(version) && version["id"] == VERSION_ID &&
             version.dig("attributes", "platform") == "IOS" && version.dig("attributes", "versionString") == MARKETING_VERSION,
             "fixed_version_identity_mismatch")
      state = version.dig("attributes", "appVersionState")
      check!((EDITABLE_STATES + SUBMITTED_VERSION_STATES).include?(state), "version_state_not_authorized")
      check!(version.dig("attributes", "releaseType") == "AFTER_APPROVAL", "release_type_must_remain_after_approval")
      link = client.get("/v1/appStoreVersions/#{VERSION_ID}/relationships/build").fetch("data")
      check!(link == { "type" => "builds", "id" => BUILD_ID }, "attached_build_identity_mismatch")
      build = client.get("/v1/builds/#{BUILD_ID}", { "fields[builds]" => "version,processingState,expired" }).fetch("data")
      check!(resource?(build, "builds") && scoped?(build) && build["id"] == BUILD_ID && build.dig("attributes", "version") == BUILD_NUMBER &&
             build.dig("attributes", "processingState") == "VALID" && build.dig("attributes", "expired") == false,
             "attached_build_must_be_exact_valid_unexpired")
      { "checked_at" => Time.now.utc.iso8601, "version_id" => VERSION_ID, "version_state" => state,
        "release_type" => "AFTER_APPROVAL", "build_id" => BUILD_ID, "build_number" => BUILD_NUMBER,
        "processing_state" => "VALID", "expired" => false }
    end
    private_class_method :read_target!

    def read_inventory!(client)
      rows = client.paginate("/v1/apps/#{APP_ID}/reviewSubmissions", {
        "filter[platform]" => "IOS", "fields[reviewSubmissions]" => "platform,state,appStoreVersionForReview",
        "include" => "appStoreVersionForReview", "limit" => "200"
      })
      seen = {}
      rows.map do |resource|
        check!(resource?(resource, "reviewSubmissions") && scoped?(resource) && resource.dig("attributes", "platform") == "IOS" &&
               STATES.include?(resource.dig("attributes", "state")) && !seen[resource["id"]], "review_batch_scope_unverified")
        id = resource.fetch("id")
        seen[id] = true
        direct = resource.dig("relationships", "appStoreVersionForReview", "data")
        direct_target = direct == { "type" => "appStoreVersions", "id" => VERSION_ID }
        items = read_items!(client, id)
        target_items = items.select do |item|
          check!(resource?(item, "reviewSubmissionItems"), "review_item_scope_unverified")
          relations = item.fetch("relationships")
          check!(relations.is_a?(Hash) && (relations.keys - RELATIONS).empty?, "item_material_relations_unknown")
          check!(relations.key?("appStoreVersion"), "required_item_version_relation_missing")
          data = relationship_data(client, item, "appStoreVersion", relations.fetch("appStoreVersion"))
          check!(data.nil? || (data.is_a?(Hash) && data["type"] == "appStoreVersions" && data["id"].is_a?(String) && data["id"].match?(RESOURCE_ID)),
                 "item_version_linkage_invalid")
          if data.nil?
            check!(relations.any? do |name, relation|
              name != "appStoreVersion" && RELATIONS.include?(name) && relation.is_a?(Hash) && relation["data"].is_a?(Hash)
            end, "item_material_identity_unverified")
          end
          data == { "type" => "appStoreVersions", "id" => VERSION_ID }
        end
        contains = direct_target || !target_items.empty?
        check!(!(id == EXCLUDED_SUBMISSION_ID && contains), "excluded_batch_has_target_binding")
        target_only = false
        if contains
          check!(direct.nil? || direct == { "type" => "appStoreVersions", "id" => VERSION_ID }, "target_batch_direct_link_conflicts")
          check!(items.length == 1 && target_items.length == 1, "target_batch_must_contain_only_one_target_item")
          verify_target_item!(client, target_items.first)
          target_only = true
        end
        { "id" => id, "state" => resource.dig("attributes", "state"), "item_count" => items.length,
          "contains_target" => contains, "direct_target" => direct_target, "target_only" => target_only,
          "item_id" => target_only ? target_items.first.fetch("id") : nil }
      end
    end
    private_class_method :read_inventory!

    def select_candidate!(inventory, target)
      candidates = inventory.select { |row| row["target_only"] }
      accepted = candidates.select { |row| ACCEPTED_STATES.include?(row["state"]) }
      if !accepted.empty?
        check!(accepted.length == 1 && candidates.length == 1 && SUBMITTED_VERSION_STATES.include?(target["version_state"]), "submitted_target_state_mismatch")
        check_no_blocker!(inventory, accepted.first.fetch("id"))
        return accepted.first
      end
      check_no_blocker!(inventory, nil)
      ready = candidates.select { |row| row["state"] == "READY_FOR_REVIEW" }
      check!(ready.length <= 1, "multiple_target_only_drafts")
      ready.first
    end
    private_class_method :select_candidate!

    def check_no_blocker!(inventory, allowed_id)
      check!(inventory.none? { |row| row["id"] != allowed_id && BLOCKING_STATES.include?(row["state"]) }, "another_ios_review_batch_is_active")
    end
    private_class_method :check_no_blocker!

    def verify_target_item!(client, item)
      relations = item.fetch("relationships")
      check!(relations.is_a?(Hash) && (relations.keys - RELATIONS).empty?, "target_item_has_unknown_material_relation")
      check!(relations.key?("appStoreVersion"), "required_item_version_relation_missing")
      # The full collection response declares the item's applicable material links.
      # Optional absent associations are not invented or fetched via unsupported endpoints.
      relations.each do |name, relation|
        data = relationship_data(client, item, name, relation)
        expected = name == "appStoreVersion" ? { "type" => "appStoreVersions", "id" => VERSION_ID } : nil
        check!(data == expected, "target_item_contains_other_or_unknown_material")
      end
    end
    private_class_method :verify_target_item!

    def read_items!(client, submission_id)
      query = { "fields[reviewSubmissionItems]" => (["state"] + RELATIONS).join(","),
                "include" => RELATIONS.join(","), "limit" => "200" }
      endpoint = "/v1/reviewSubmissions/#{submission_id}/items"
      items = client.paginate(endpoint, query)
      check!(items.is_a?(Array), "review_items_not_a_list")
      unresolved = items.any? do |item|
        check!(resource?(item, "reviewSubmissionItems"), "review_item_scope_unverified")
        relations = item.fetch("relationships")
        check!(relations.is_a?(Hash) && (relations.keys - RELATIONS).empty?, "item_material_relations_unknown")
        relations.any? { |_name, relation| !relation.is_a?(Hash) || !relation.key?("data") }
      end
      # Apple exposes linkage through this collection, not per-item relationship GET endpoints.
      if unresolved
        items = client.paginate(endpoint, query)
        check!(items.is_a?(Array), "review_items_not_a_list")
      end
      items.each do |item|
        check!(resource?(item, "reviewSubmissionItems"), "review_item_scope_unverified")
        relations = item.fetch("relationships")
        check!(relations.is_a?(Hash) && (relations.keys - RELATIONS).empty?, "item_material_relations_unknown")
        check!(relations.values.all? { |relation| relation.is_a?(Hash) && relation.key?("data") }, "review_item_relation_unresolved")
      end
      items
    end
    private_class_method :read_items!

    def relationship_data(_client, _item, _name, relation)
      check!(relation.is_a?(Hash) && relation.key?("data"), "review_item_relation_unresolved")
      relation["data"]
    end
    private_class_method :relationship_data

    def candidate_receipt(row)
      row.slice("id", "state", "item_id", "item_count", "target_only")
    end
    private_class_method :candidate_receipt
  end
end
