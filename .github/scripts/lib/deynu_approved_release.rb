# frozen_string_literal: true

require_relative "asc_review_status"

module MajiaCI
  class DeynuReleaseError < StandardError; end

  module DeynuApprovedRelease
    module_function

    BUNDLE_ID = "com.almanac.lite"
    APP_ID = "6824457290"
    VERSION = "1.0.2"
    VERSION_ID = "676b323f-1a54-4d86-b8e0-0b79baaf340c"
    BUILD_ID = "35351e2e-1b0c-45bd-a0d4-ba087083deed"
    BUILD_NUMBER = "1"
    READY_STATES = %w[READY_FOR_DISTRIBUTION READY_FOR_SALE].freeze
    VERSION_PATH = "/v1/appStoreVersions/#{VERSION_ID}"

    def base_summary(execute: false, checked_at: Time.now.utc)
      {
        "schema_version" => 1,
        "checked_at" => checked_at.utc.iso8601,
        "app" => { "id" => APP_ID, "bundle_id" => BUNDLE_ID },
        "version" => { "id" => VERSION_ID, "version_string" => VERSION, "platform" => "IOS" },
        "build" => { "id" => BUILD_ID, "version" => BUILD_NUMBER },
        "execution_requested" => execute,
        "post_attempted" => false,
        "request_accepted" => false,
        "release_request_id" => nil,
        "distribution_ready" => false,
        "no_op" => false,
        "evidence_boundary" => "An accepted release request is not proof of public distribution. No write is retried."
      }
    end

    def release(client:, execute: false, run_attempt: "1", checkpoint: nil, checked_at: Time.now.utc)
      summary = base_summary(execute: execute, checked_at: checked_at)
      post_started = false
      read_after_post_started = false
      preflight!(client, summary)
      if READY_STATES.include?(summary.dig("version", "app_version_state"))
        summary.merge!("distribution_ready" => true, "no_op" => true, "no_op_reason" => "already_distributed")
        return summary
      end
      unless summary.dig("version", "app_version_state") == "PENDING_DEVELOPER_RELEASE" &&
             summary.dig("version", "release_type") == "MANUAL"
        raise DeynuReleaseError, "version_not_pending_manual_release"
      end
      unless execute && run_attempt.to_s == "1"
        summary.merge!(
          "no_op" => true,
          "no_op_reason" => run_attempt.to_s == "1" ? "dry_run" : "workflow_attempt_not_first"
        )
        return summary
      end

      # Persistence is mandatory before the irreversible, single POST.
      raise DeynuReleaseError, "intent_checkpoint_required" unless checkpoint

      summary["post_attempted"] = true
      checkpoint.call(summary)
      post_started = true
      response = client.post_created("/v1/appStoreVersionReleaseRequests", {
        "data" => {
          "type" => "appStoreVersionReleaseRequests",
          "relationships" => {
            "appStoreVersion" => { "data" => { "type" => "appStoreVersions", "id" => VERSION_ID } }
          }
        }
      })
      data = response.fetch("data")
      unless data["type"] == "appStoreVersionReleaseRequests" &&
             data["id"].is_a?(String) && data["id"].match?(/\A[A-Za-z0-9-]{1,100}\z/)
        raise DeynuReleaseError, "release_response_ambiguous"
      end
      summary["release_request_id"] = data.fetch("id")
      summary["request_accepted"] = true
      checkpoint.call(summary)
      read_after_post_started = true
      read_after_post!(client, summary)
      summary
    rescue StandardError => error
      summary["post_attempted"] = false unless post_started
      if post_started && !summary["request_accepted"] && (status = error.message.match(/\bHTTP (\d{3})\b/))
        summary["post_http_status"] = status[1].to_i
      end
      summary["error_code"] = if error.is_a?(DeynuReleaseError)
                                error.message
                              elsif post_started
                                summary["request_accepted"] ? "post_snapshot_failed" : "release_request_unconfirmed"
                              else
                                "preflight_or_checkpoint_failed"
                              end
      if post_started && !read_after_post_started
        begin
          read_after_post!(client, summary)
        rescue StandardError
          summary["post_snapshot_error"] = "read_failed"
        end
      end
      summary
    end

    def preflight!(client, summary)
      app = client.get("/v1/apps/#{APP_ID}", { "fields[apps]" => "bundleId" }).fetch("data")
      unless app["type"] == "apps" && app["id"] == APP_ID && app.dig("attributes", "bundleId") == BUNDLE_ID
        raise DeynuReleaseError, "app_identity_mismatch"
      end
      versions = client.paginate("/v1/apps/#{APP_ID}/appStoreVersions", {
        "filter[platform]" => "IOS", "filter[versionString]" => VERSION,
        "fields[appStoreVersions]" => "platform,versionString,appVersionState,releaseType", "limit" => "2"
      })
      unless versions.is_a?(Array) && versions.length == 1
        raise DeynuReleaseError, "version_identity_mismatch"
      end
      version = versions.first
      validate_version!(version)
      relationship = client.get("#{VERSION_PATH}/relationships/build").fetch("data")
      unless relationship.is_a?(Hash) && relationship["type"] == "builds" && relationship["id"] == BUILD_ID
        raise DeynuReleaseError, "build_identity_mismatch"
      end
      build = client.get("/v1/builds/#{BUILD_ID}", {
        "fields[builds]" => "version,processingState,expired"
      }).fetch("data")
      unless build["type"] == "builds" && build["id"] == BUILD_ID &&
             build.dig("attributes", "version") == BUILD_NUMBER &&
             build.dig("attributes", "processingState") == "VALID" &&
             build.dig("attributes", "expired") == false
        raise DeynuReleaseError, "build_not_exact_valid_unexpired"
      end
      summary["version"].merge!(version_snapshot(version))
      summary["build"].merge!("processing_state" => "VALID", "expired" => false)
    end
    private_class_method :preflight!

    def validate_version!(version)
      unless version.is_a?(Hash) && version["type"] == "appStoreVersions" && version["id"] == VERSION_ID &&
             version.dig("attributes", "versionString") == VERSION && version.dig("attributes", "platform") == "IOS"
        raise DeynuReleaseError, "version_identity_mismatch"
      end
    end
    private_class_method :validate_version!

    def version_snapshot(version)
      attributes = version.fetch("attributes")
      %w[appVersionState releaseType].zip(%w[app_version_state release_type]).to_h do |source, target|
        value = attributes[source]
        [target, value.is_a?(String) && value.match?(/\A[A-Z_]{1,60}\z/) ? value : "UNKNOWN"]
      end
    end
    private_class_method :version_snapshot

    def read_after_post!(client, summary)
      version = client.get(VERSION_PATH, {
        "fields[appStoreVersions]" => "platform,versionString,appVersionState,releaseType"
      }).fetch("data")
      validate_version!(version)
      summary["post_snapshot"] = version_snapshot(version)
      summary["distribution_ready"] = READY_STATES.include?(summary.dig("post_snapshot", "app_version_state"))
    end
    private_class_method :read_after_post!
  end
end
