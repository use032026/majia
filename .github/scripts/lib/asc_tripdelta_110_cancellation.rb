# frozen_string_literal: true

require_relative "asc_review_cancellation"

module MajiaCI
  module ASCTripDelta110Cancellation
    module_function

    APP_ID = "6822704143"
    BUNDLE_ID = "com.tripdelta.lite.app"
    MARKETING_VERSION = "1.0.10"
    VERSION_ID = "f991521a-405e-4422-be57-6f1dec949af2"
    SUBMISSION_ID = "d4a41c28-03b0-4c43-b466-a5936ee24593"
    OLD_BUILD_ID = "a130321b-d00b-4cda-95ca-d66d00e2c7e8"
    OLD_BUILD_NUMBER = "1"
    UUID = /\A[0-9a-fA-F]{8}(?:-[0-9a-fA-F]{4}){3}-[0-9a-fA-F]{12}\z/
    ID = /\A[A-Za-z0-9_-]{1,128}\z/
    ACTIVE = %w[WAITING_FOR_REVIEW IN_REVIEW].freeze
    STATES = (ACTIVE + %w[CANCELING COMPLETE]).freeze

    def cancel(client:, replacement_build_id:, replacement_build_number:, execute: false,
               poll_seconds: 5, max_polls: 24, sleeper: ->(seconds) { sleep(seconds) })
      evidence = {
        "schema_version" => 1, "requested_app_id" => APP_ID, "requested_bundle_id" => BUNDLE_ID,
        "requested_marketing_version" => MARKETING_VERSION, "requested_version_id" => VERSION_ID,
        "requested_submission_id" => SUBMISSION_ID, "execute" => execute == true,
        "cancel_requested" => false, "completed" => false, "no_op" => false,
        "evidence_boundary" => "Only cancels the fixed old Trip Delta review batch after verifying its replacement upload. Does not change builds, submit or release."
      }
      check!([true, false].include?(execute), "execute must be a boolean")
      check!(replacement_build_id.is_a?(String) && replacement_build_id.match?(UUID) &&
             replacement_build_id.downcase != OLD_BUILD_ID, "replacement build ID must be a different UUID")
      check!(replacement_build_number.is_a?(String) && replacement_build_number.match?(/\A[1-9]\d{0,17}\z/) &&
             replacement_build_number.to_i > 1, "replacement build number must be greater than one")
      check!(max_polls.is_a?(Integer) && max_polls.between?(1, 120) && poll_seconds.is_a?(Numeric) &&
             poll_seconds.finite? && poll_seconds.between?(0, 30), "invalid polling limits")
      evidence["replacement_build_id"] = replacement_build_id
      evidence["replacement_build_number"] = replacement_build_number
      verify_app!(client)
      verify_submission_scope!(client)
      before = snapshot(client)
      evidence["before"] = before
      evidence["after"] = before
      if complete?(before)
        evidence["completed"] = true
        evidence["no_op"] = true
        return evidence
      end
      verify_active!(before)
      evidence["verified_item"] = verify_items!(client)
      evidence["replacement"] = replacement_gate!(client, replacement_build_id, replacement_build_number)
      unless execute
        evidence["dry_run"] = true
        evidence["ready_to_cancel"] = true
        return evidence
      end

      # Refresh both scopes and the complete replacement gate immediately before the only mutation.
      verify_app!(client)
      verify_submission_scope!(client)
      fresh = snapshot(client)
      evidence["after"] = fresh
      if complete?(fresh)
        evidence["completed"] = true
        evidence["no_op"] = true
        return evidence
      end
      verify_active!(fresh)
      evidence["verified_item"] = verify_items!(client)
      evidence["replacement"] = replacement_gate!(client, replacement_build_id, replacement_build_number)
      if fresh["submission_state"] == "CANCELING"
        evidence["no_op"] = true
      else
        evidence["cancel_requested"] = true
        begin
          client.patch("/v1/reviewSubmissions/#{SUBMISSION_ID}", {
            "data" => { "type" => "reviewSubmissions", "id" => SUBMISSION_ID,
                        "attributes" => { "canceled" => true } }
          })
        rescue StandardError
          begin
            evidence["after"] = snapshot(client)
          rescue StandardError
            evidence["readback_failed"] = true
          end
          raise ASCCancellationError.new("cancellation PATCH outcome requires readback; never retry blindly", evidence: evidence)
        end
      end
      max_polls.times do |index|
        sleeper.call(poll_seconds) if index.positive?
        observed = snapshot(client)
        evidence["after"] = observed
        if complete?(observed)
          evidence["completed"] = true
          return evidence
        end
        # Separate GETs may see COMPLETE just before the version read reflects the withdrawal.
        check!(STATES.include?(observed["submission_state"]), "unexpected cancellation readback state")
      end
      raise ASCCancellationError, "cancellation not confirmed within polling limit"
    rescue ASCCancellationError => error
      raise error if error.evidence

      raise ASCCancellationError.new(error.message, evidence: evidence)
    rescue StandardError
      raise ASCCancellationError.new("cancellation scope or replacement could not be verified", evidence: evidence)
    end

    def check!(condition, message)
      raise ASCCancellationError, message unless condition
    end
    private_class_method :check!

    def resource?(value, type, id = nil)
      value.is_a?(Hash) && value["type"] == type && value["id"].is_a?(String) && value["id"].match?(ID) &&
        (id.nil? || value["id"] == id) && value["attributes"].is_a?(Hash)
    end
    private_class_method :resource?

    def scoped?(resource)
      relation = resource.dig("relationships", "app")
      return true if relation.nil? || (relation.is_a?(Hash) && !relation.key?("data"))

      relation.is_a?(Hash) && relation["data"] == { "type" => "apps", "id" => APP_ID }
    end
    private_class_method :scoped?

    def verify_app!(client)
      apps = client.paginate("/v1/apps", { "filter[bundleId]" => BUNDLE_ID, "fields[apps]" => "bundleId", "limit" => "2" })
      check!(apps.is_a?(Array) && apps.length == 1 && resource?(apps.first, "apps", APP_ID) &&
             apps.first.dig("attributes", "bundleId") == BUNDLE_ID, "fixed app identity mismatch")
    end
    private_class_method :verify_app!

    def verify_submission_scope!(client)
      submissions = client.paginate("/v1/apps/#{APP_ID}/reviewSubmissions", { "filter[platform]" => "IOS", "limit" => "200" })
      matches = submissions.select { |resource| resource.is_a?(Hash) && resource["id"] == SUBMISSION_ID }
      check!(matches.length == 1 && resource?(matches.first, "reviewSubmissions", SUBMISSION_ID) &&
             matches.first.dig("attributes", "platform") == "IOS" && scoped?(matches.first), "fixed submission app scope mismatch")
    end
    private_class_method :verify_submission_scope!

    def snapshot(client)
      versions = client.paginate("/v1/apps/#{APP_ID}/appStoreVersions", {
        "filter[platform]" => "IOS", "filter[versionString]" => MARKETING_VERSION,
        "fields[appStoreVersions]" => "platform,versionString,appVersionState", "limit" => "200"
      })
      check!(versions.is_a?(Array) && versions.length == 1, "fixed version was not unique")
      version = versions.first
      check!(resource?(version, "appStoreVersions", VERSION_ID) && scoped?(version) &&
             version.dig("attributes", "platform") == "IOS" && version.dig("attributes", "versionString") == MARKETING_VERSION,
             "fixed version identity mismatch")
      state = version.dig("attributes", "appVersionState")
      check!((ACTIVE + ["DEVELOPER_REJECTED"]).include?(state), "fixed version has unexpected review state")
      submission = client.get("/v1/reviewSubmissions/#{SUBMISSION_ID}").fetch("data")
      check!(resource?(submission, "reviewSubmissions", SUBMISSION_ID) && scoped?(submission) &&
             submission.dig("attributes", "platform") == "IOS" && STATES.include?(submission.dig("attributes", "state")),
             "fixed submission identity or state mismatch")
      build_link = client.get("/v1/appStoreVersions/#{VERSION_ID}/relationships/build").fetch("data")
      check!(build_link == { "type" => "builds", "id" => OLD_BUILD_ID }, "old attached build changed")
      build = client.get("/v1/builds/#{OLD_BUILD_ID}", { "fields[builds]" => "version,processingState,expired" }).fetch("data")
      check!(resource?(build, "builds", OLD_BUILD_ID) && build.dig("attributes", "version") == OLD_BUILD_NUMBER,
             "old attached build number changed")
      { "checked_at" => Time.now.utc.iso8601, "version_id" => VERSION_ID, "version_state" => state,
        "submission_id" => SUBMISSION_ID, "submission_state" => submission.dig("attributes", "state"),
        "build" => { "id" => OLD_BUILD_ID, "version" => OLD_BUILD_NUMBER } }
    end
    private_class_method :snapshot

    def verify_active!(observed)
      check!(ACTIVE.include?(observed["submission_state"]) || observed["submission_state"] == "CANCELING", "fixed batch is no longer cancellable")
      check!(ACTIVE.include?(observed["version_state"]) || observed["submission_state"] == "CANCELING", "fixed version is no longer in review")
    end
    private_class_method :verify_active!

    def complete?(observed)
      observed["submission_state"] == "COMPLETE" && observed["version_state"] == "DEVELOPER_REJECTED"
    end
    private_class_method :complete?

    def verify_items!(client)
      items = client.paginate("/v1/reviewSubmissions/#{SUBMISSION_ID}/items", { "include" => "appStoreVersion", "limit" => "200" })
      check!(items.is_a?(Array) && items.length == 1 && resource?(items.first, "reviewSubmissionItems"), "fixed batch must have exactly one review item")
      item = items.first
      relations = item.fetch("relationships")
      check!(relations.is_a?(Hash), "review item relationships are missing")
      target = relation_data(client, item, "appStoreVersion", relations.fetch("appStoreVersion"))
      check!(target == { "type" => "appStoreVersions", "id" => VERSION_ID }, "review item targets another version")
      relations.each do |name, relationship|
        next if name == "appStoreVersion"
        check!(ASCReviewCancellation::ITEM_RELATIONSHIPS.include?(name), "review item has unknown material relationship")
        check!(relation_data(client, item, name, relationship).nil?, "review item contains another material")
      end
      { "id" => item.fetch("id"), "app_store_version" => target }
    end
    private_class_method :verify_items!

    def relation_data(client, item, name, relation)
      check!(relation.is_a?(Hash), "malformed review item relationship")
      return relation["data"] if relation.key?("data")

      expected = "/v1/reviewSubmissionItems/#{item.fetch('id')}/relationships/#{name}"
      link = relation.dig("links", "self")
      check!([expected, ASCReviewStatus::API_ORIGIN + expected].include?(link), "review item relationship is not verifiable")
      response = client.get(expected)
      check!(response.is_a?(Hash) && response.key?("data"), "review item relationship response is missing")
      response["data"]
    end
    private_class_method :relation_data

    def replacement_gate!(client, build_id, build_number)
      prereleases = client.paginate("/v1/apps/#{APP_ID}/preReleaseVersions", {
        "fields[preReleaseVersions]" => "platform,version", "limit" => "200"
      })
      exact = prereleases.select do |resource|
        resource?(resource, "preReleaseVersions") && scoped?(resource) &&
          resource.dig("attributes", "platform") == "IOS" && resource.dig("attributes", "version") == MARKETING_VERSION
      end
      check!(exact.length == 1, "replacement prerelease version scope is not unique")
      builds = client.paginate("/v1/preReleaseVersions/#{exact.first.fetch('id')}/builds", {
        "fields[builds]" => "version,processingState,expired", "limit" => "200"
      })
      matches = builds.select { |build| build.dig("attributes", "version") == build_number }
      check!(matches.length == 1 && resource?(matches.first, "builds", build_id) && scoped?(matches.first) &&
             matches.first.dig("attributes", "processingState") == "VALID" && matches.first.dig("attributes", "expired") == false,
             "replacement exact build is not VALID and unexpired in the fixed app version")
      uploads = client.paginate("/v1/apps/#{APP_ID}/buildUploads", {
        "fields[buildUploads]" => "cfBundleShortVersionString,cfBundleVersion,state,platform,build", "include" => "build", "limit" => "200"
      })
      matches = uploads.select do |upload|
        resource?(upload, "buildUploads") && scoped?(upload) && upload.dig("attributes", "platform") == "IOS" &&
          upload.dig("attributes", "cfBundleShortVersionString") == MARKETING_VERSION && upload.dig("attributes", "cfBundleVersion") == build_number
      end
      check!(matches.length == 1 && matches.first.dig("attributes", "state", "state") == "COMPLETE", "replacement upload is not uniquely COMPLETE")
      upload = matches.first
      check!(upload.dig("relationships", "build", "data") == { "type" => "builds", "id" => build_id },
             "replacement upload must explicitly identify the exact new build")
      { "checked_at" => Time.now.utc.iso8601, "app_id" => APP_ID, "platform" => "IOS", "marketing_version" => MARKETING_VERSION,
        "build_id" => build_id, "build_number" => build_number, "processing_state" => "VALID", "expired" => false,
        "upload_id" => upload.fetch("id"), "upload_state" => "COMPLETE",
        "association" => "explicit upload-to-build linkage and same app-scoped exact prerelease version; upload ID is not assumed equal to build ID" }
    end
    private_class_method :replacement_gate!
  end
end
