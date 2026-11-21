# frozen_string_literal: true

require "date"
require_relative "asc_review_status"

module MajiaCI
  # A lower bound from currently observable, app-scoped review evidence, never a lifetime total.
  module ASCReviewHistory
    MAX_PAGES = 20
    RESOURCE_ID = /\A[A-Za-z0-9_-]{1,128}\z/
    APP_ID = /\A[1-9]\d{0,19}\z/
    SUBMITTED_VERSION_STATES = %w[
      WAITING_FOR_REVIEW IN_REVIEW ACCEPTED PENDING_DEVELOPER_RELEASE PENDING_APPLE_RELEASE
      READY_FOR_DISTRIBUTION READY_FOR_SALE PROCESSING_FOR_DISTRIBUTION PROCESSING_FOR_APP_STORE
      REJECTED METADATA_REJECTED DEVELOPER_REJECTED INVALID_BINARY
    ].freeze
    DRAFT_VERSION_STATES = %w[PREPARE_FOR_SUBMISSION READY_FOR_REVIEW].freeze
    SUBMISSION_STATES = %w[
      READY_FOR_REVIEW WAITING_FOR_REVIEW IN_REVIEW UNRESOLVED_ISSUES CANCELING COMPLETING COMPLETE
    ].freeze
    ITEM_STATES = %w[READY_FOR_REVIEW ACCEPTED APPROVED REJECTED REMOVED].freeze
    REVIEWED_ITEM_STATES = %w[ACCEPTED APPROVED REJECTED].freeze
    VERSION_FIELDS = "platform,versionString,appVersionState"
    SUBMISSION_FIELDS = "platform,submittedDate,state,appStoreVersionForReview"

    def self.read(client:, bundle_id:, checked_at: Time.now.utc)
      unless bundle_id.is_a?(String) && bundle_id.match?(ASCReviewStatus::BUNDLE_ID_PATTERN)
        raise ASCStatusError, "IOS_BUNDLE_ID is invalid"
      end

      Reader.new(client, bundle_id, checked_at).read
    end

    class Reader
      def initialize(client, bundle_id, checked_at)
        @client = client
        @bundle_id = bundle_id
        @checked_at = checked_at
        @complete = true
        @errors = []
        @unknowns = []
        @confirmed = {}
      end

      def read
        apps = pages("/v1/apps", {
          "filter[bundleId]" => @bundle_id, "fields[apps]" => "bundleId", "limit" => "2"
        }, "apps")
        app = apps.first
        unless @complete && apps.length == 1 && resource?(app, "apps") &&
               app["id"].match?(APP_ID) && app.dig("attributes", "bundleId") == @bundle_id
          gap("app_identity_unverified", "apps")
          return result(nil)
        end

        @app_id = app.fetch("id")
        versions = pages("/v1/apps/#{@app_id}/appStoreVersions", {
          "filter[platform]" => "IOS", "fields[appStoreVersions]" => VERSION_FIELDS, "limit" => "200"
        }, "versions")
        @versions = version_map(versions)
        @versions.each_value do |version|
          if SUBMITTED_VERSION_STATES.include?(version.fetch("state"))
            confirm(version, { "kind" => "app_store_version_state", "state" => version.fetch("state") })
          elsif !DRAFT_VERSION_STATES.include?(version.fetch("state"))
            gap("unconfirmed_version_state", "versions", version.fetch("id"))
          end
        end

        submissions = pages("/v1/apps/#{@app_id}/reviewSubmissions", {
          "filter[platform]" => "IOS", "fields[reviewSubmissions]" => SUBMISSION_FIELDS, "limit" => "200"
        }, "submissions")
        submissions.each { |submission| read_submission(submission) }
        result(@app_id)
      end

      private

      def pages(path, query, scope)
        rows = []
        target = path
        params = query
        seen = {}
        MAX_PAGES.times do
          key = request_key(target, params)
          if seen[key]
            error("pagination_loop", scope)
            return rows
          end
          seen[key] = true
          begin
            document = @client.get(target, params)
          rescue ASCPermissionError
            error("permission_denied", scope)
            return rows
          rescue ASCStatusError
            error("request_failed", scope)
            return rows
          end
          unless document.is_a?(Hash) && document["data"].is_a?(Array)
            error("invalid_list_response", scope)
            return rows
          end
          rows.concat(document.fetch("data"))
          links = document["links"]
          unless links.nil? || links.is_a?(Hash)
            error("invalid_pagination_links", scope)
            return rows
          end
          target = links && links["next"]
          return rows if target.nil? || target == ""

          unless safe_next?(target, path)
            error("unsafe_pagination_link", scope)
            return rows
          end
          params = nil
        end
        error("pagination_limit", scope)
        rows
      end

      def safe_next?(target, expected_path)
        return false unless target.is_a?(String) && !target.match?(/[\x00-\x20\x7f]/)

        uri = URI.parse(target)
        absolute = uri.scheme == "https" && uri.host == "api.appstoreconnect.apple.com" && uri.port == 443
        relative = uri.scheme.nil? && uri.host.nil? && target.start_with?("/") && !target.start_with?("//")
        (absolute || relative) && uri.userinfo.nil? && uri.fragment.nil? && uri.path == expected_path
      rescue URI::InvalidURIError
        false
      end

      def request_key(target, query)
        uri = URI.parse(target.start_with?("/") ? "#{ASCReviewStatus::API_ORIGIN}#{target}" : target)
        uri.query = URI.encode_www_form(query) if query
        uri.to_s
      end

      def version_map(rows)
        versions = {}
        conflicting = {}
        rows.each do |resource|
          unless resource?(resource, "appStoreVersions") && scoped_to_app?(resource) &&
                 resource.dig("attributes", "platform") == "IOS"
            gap("version_scope_unverified", "versions", safe_id(resource))
            next
          end
          attributes = resource.fetch("attributes")
          marketing = attributes["versionString"]
          state = attributes["appVersionState"] || attributes["appStoreState"]
          unless marketing.is_a?(String) && marketing.bytesize <= 32 && marketing.match?(ASCReviewStatus::VERSION_PATTERN) &&
                 state.is_a?(String) && state.match?(/\A[A-Z][A-Z_]{0,79}\z/)
            gap("invalid_version_attributes", "versions", resource.fetch("id"))
            next
          end
          version = { "id" => resource.fetch("id"), "marketing_version" => marketing, "state" => state }
          if versions.key?(version["id"]) && versions[version["id"]] != version
            conflicting[version["id"]] = true
            gap("conflicting_version_resource", "versions", version["id"])
          end
          versions[version["id"]] = version
        end
        conflicting.each_key { |id| versions.delete(id) }
        versions
      end

      def read_submission(submission)
        unless resource?(submission, "reviewSubmissions") && scoped_to_app?(submission) &&
               submission.dig("attributes", "platform") == "IOS"
          gap("submission_scope_unverified", "submissions", safe_id(submission))
          return
        end
        id = submission.fetch("id")
        state = submission.dig("attributes", "state")
        unless SUBMISSION_STATES.include?(state)
          gap("unknown_submission_state", "submissions", id)
          return
        end
        submitted_date = timestamp(submission.dig("attributes", "submittedDate"))
        direct = version_link(submission, "appStoreVersionForReview")
        if direct && !@versions.key?(direct)
          gap("submission_version_out_of_scope", "submissions", id)
          return
        end
        items = pages("/v1/reviewSubmissions/#{id}/items", {
          "fields[reviewSubmissionItems]" => "state,appStoreVersion", "include" => "appStoreVersion", "limit" => "200"
        }, "submission_items")
        items.each do |item|
          unless resource?(item, "reviewSubmissionItems") && ITEM_STATES.include?(item.dig("attributes", "state"))
            gap("invalid_submission_item", "submission_items", safe_id(item))
            next
          end
          relationships = item["relationships"]
          unless relationships.is_a?(Hash)
            gap("missing_item_relationships", "submission_items", item.fetch("id"))
            next
          end
          relationship = relationships["appStoreVersion"]
          if relationship.nil?
            # Other reviewable resource types are not app version submissions.
            if relationships.any? { |name, value| name != "appStoreVersion" && value.is_a?(Hash) && value["data"].is_a?(Hash) }
              next
            end
            gap("missing_item_version_relationship", "submission_items", item.fetch("id"))
            next
          end
          unless relationship.is_a?(Hash) && relationship.key?("data")
            gap("unresolved_item_version_relationship", "submission_items", item.fetch("id"))
            next
          end
          next if relationship["data"].nil?

          version_id = version_link(item, "appStoreVersion")
          unless version_id && @versions.key?(version_id)
            gap("item_version_out_of_scope", "submission_items", item.fetch("id"))
            next
          end
          item_state = item.dig("attributes", "state")
          next if item_state == "REMOVED"
          next if state == "READY_FOR_REVIEW" && submitted_date.nil?

          strong_item = REVIEWED_ITEM_STATES.include?(item_state)
          queued_target = %w[WAITING_FOR_REVIEW IN_REVIEW].include?(state) && direct == version_id
          if submitted_date && state != "READY_FOR_REVIEW" && (strong_item || queued_target)
            confirm(@versions.fetch(version_id), {
              "kind" => "review_submission_item", "submission_id" => id, "item_id" => item.fetch("id"),
              "submitted_date" => submitted_date, "state" => state, "item_state" => item_state
            })
          else
            gap("unproven_item_submission", "submission_items", item.fetch("id"))
          end
        end
      end

      def resource?(resource, type)
        resource.is_a?(Hash) && resource["type"] == type && safe_id(resource) && resource["attributes"].is_a?(Hash)
      end

      def scoped_to_app?(resource)
        relationships = resource["relationships"]
        return true if relationships.nil?
        return false unless relationships.is_a?(Hash)
        return true unless relationships.key?("app")

        relationship = relationships["app"]
        return false unless relationship.is_a?(Hash)
        # The parent listing establishes app scope; optional links-only app relations add no contradiction.
        return true unless relationship.key?("data")

        link = relationship["data"]
        link.is_a?(Hash) && link["type"] == "apps" && link["id"] == @app_id
      end

      def safe_id(resource)
        id = resource.is_a?(Hash) && resource["id"]
        id if id.is_a?(String) && id.match?(RESOURCE_ID)
      end

      def version_link(resource, name)
        relationship = resource.dig("relationships", name)
        return nil unless relationship.is_a?(Hash)

        link = relationship["data"]
        safe_id(link) if link.is_a?(Hash) && link["type"] == "appStoreVersions"
      end

      def timestamp(value)
        return nil unless value.is_a?(String) && value.match?(/\A\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}(?:\.\d{1,9})?(?:Z|[+-]\d{2}:\d{2})\z/)

        Date.iso8601(value[0, 10])
        Time.iso8601(value).utc.iso8601
      rescue ArgumentError
        nil
      end

      def confirm(version, evidence)
        entry = (@confirmed[version.fetch("marketing_version")] ||= {
          "marketing_version" => version.fetch("marketing_version"), "version_ids" => [],
          "app_version_states" => [], "evidence" => []
        })
        entry["version_ids"] |= [version.fetch("id")]
        entry["app_version_states"] |= [version.fetch("state")]
        entry["evidence"] |= [evidence]
      end

      def error(code, scope)
        @complete = false
        @errors << { "code" => code, "scope" => scope }
      end

      def gap(code, scope, id = nil)
        @complete = false
        item = { "code" => code, "scope" => scope }
        item["resource_id"] = id if id
        @unknowns |= [item]
      end

      def result(app_id)
        versions = @confirmed.values.sort_by { |entry| entry.fetch("marketing_version").split(".").map(&:to_i) }
        count = versions.length
        {
          "schema_version" => 1, "checked_at" => @checked_at.utc.iso8601,
          "app" => { "id" => app_id, "bundle_id" => @bundle_id }, "platform" => "IOS",
          "confirmed_distinct_submitted_lower_bound" => count, "distinct_versions" => versions,
          "api_scan_complete" => @complete, "history_complete" => false,
          "decision" => { "label" => count >= 9 ? "可使用" : "待核实", "stop_auto_submission" => count >= 9 ? true : nil },
          "errors" => @errors, "unknowns" => @unknowns,
          "evidence_boundary" => "Read-only lower bound. Apple exposes recent and current review submissions; exhausted API pages do not prove complete lifetime history. Drafts, uploads, repeated builds and retries are not distinct submitted marketing versions."
        }
      end
    end
  end
end
