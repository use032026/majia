# frozen_string_literal: true

require_relative "asc_review_status"

module MajiaCI
  class ASCApprovedReleaseError < StandardError; end

  class ASCApprovedVersionRelease
    READY_STATES = %w[READY_FOR_DISTRIBUTION READY_FOR_SALE].freeze

    def initialize(bundle_id:, app_id:, version:, version_id:, build_id:, build_number:)
      @bundle_id = bundle_id
      @app_id = app_id
      @version = version
      @version_id = version_id
      @build_id = build_id
      @build_number = build_number
      @version_path = "/v1/appStoreVersions/#{version_id}"
    end

    def base_summary(execute: false, checked_at: Time.now.utc)
      {
        "schema_version" => 1,
        "checked_at" => checked_at.utc.iso8601,
        "app" => { "id" => @app_id, "bundle_id" => @bundle_id },
        "version" => { "id" => @version_id, "version_string" => @version, "platform" => "IOS" },
        "build" => { "id" => @build_id, "version" => @build_number },
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
        raise ASCApprovedReleaseError, "version_not_pending_manual_release"
      end
      unless execute && run_attempt.to_s == "1"
        summary.merge!(
          "no_op" => true,
          "no_op_reason" => run_attempt.to_s == "1" ? "dry_run" : "workflow_attempt_not_first"
        )
        return summary
      end

      # Persistence is mandatory before the irreversible, single POST.
      raise ASCApprovedReleaseError, "intent_checkpoint_required" unless checkpoint

      summary["post_attempted"] = true
      checkpoint.call(summary)
      post_started = true
      response = client.post_created("/v1/appStoreVersionReleaseRequests", {
        "data" => {
          "type" => "appStoreVersionReleaseRequests",
          "relationships" => {
            "appStoreVersion" => { "data" => { "type" => "appStoreVersions", "id" => @version_id } }
          }
        }
      })
      data = response.fetch("data")
      unless data["type"] == "appStoreVersionReleaseRequests" &&
             data["id"].is_a?(String) && data["id"].match?(/\A[A-Za-z0-9-]{1,100}\z/)
        raise ASCApprovedReleaseError, "release_response_ambiguous"
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
      summary["error_code"] = if error.is_a?(ASCApprovedReleaseError)
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

    private

    def preflight!(client, summary)
      app = client.get("/v1/apps/#{@app_id}", { "fields[apps]" => "bundleId" }).fetch("data")
      unless app["type"] == "apps" && app["id"] == @app_id && app.dig("attributes", "bundleId") == @bundle_id
        raise ASCApprovedReleaseError, "app_identity_mismatch"
      end
      versions = client.paginate("/v1/apps/#{@app_id}/appStoreVersions", {
        "filter[platform]" => "IOS", "filter[versionString]" => @version,
        "fields[appStoreVersions]" => "platform,versionString,appVersionState,releaseType", "limit" => "2"
      })
      unless versions.is_a?(Array) && versions.length == 1
        raise ASCApprovedReleaseError, "version_identity_mismatch"
      end
      version = versions.first
      validate_version!(version)
      relationship = client.get("#{@version_path}/relationships/build").fetch("data")
      unless relationship.is_a?(Hash) && relationship["type"] == "builds" && relationship["id"] == @build_id
        raise ASCApprovedReleaseError, "build_identity_mismatch"
      end
      build = client.get("/v1/builds/#{@build_id}", {
        "fields[builds]" => "version,processingState,expired"
      }).fetch("data")
      unless build["type"] == "builds" && build["id"] == @build_id &&
             build.dig("attributes", "version") == @build_number &&
             build.dig("attributes", "processingState") == "VALID" &&
             build.dig("attributes", "expired") == false
        raise ASCApprovedReleaseError, "build_not_exact_valid_unexpired"
      end
      summary["version"].merge!(version_snapshot(version))
      summary["build"].merge!("processing_state" => "VALID", "expired" => false)
    end

    def validate_version!(version)
      unless version.is_a?(Hash) && version["type"] == "appStoreVersions" && version["id"] == @version_id &&
             version.dig("attributes", "versionString") == @version && version.dig("attributes", "platform") == "IOS"
        raise ASCApprovedReleaseError, "version_identity_mismatch"
      end
    end

    def version_snapshot(version)
      attributes = version.fetch("attributes")
      %w[appVersionState releaseType].zip(%w[app_version_state release_type]).to_h do |source, target|
        value = attributes[source]
        [target, value.is_a?(String) && value.match?(/\A[A-Z_]{1,60}\z/) ? value : "UNKNOWN"]
      end
    end

    def read_after_post!(client, summary)
      version = client.get(@version_path, {
        "fields[appStoreVersions]" => "platform,versionString,appVersionState,releaseType"
      }).fetch("data")
      validate_version!(version)
      summary["post_snapshot"] = version_snapshot(version)
      summary["distribution_ready"] = READY_STATES.include?(summary.dig("post_snapshot", "app_version_state"))
    end
  end
end
