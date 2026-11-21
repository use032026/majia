# frozen_string_literal: true

require "digest"
require_relative "asc_review_status"

module MajiaCI
  module ASCReviewNotes
    module_function

    RESOURCE_ID = /\A[A-Za-z0-9_-]{1,128}\z/
    APP_ID = /\A[1-9]\d{0,19}\z/

    def read(client:, bundle_id:, marketing_version:, checked_at: Time.now.utc)
      unless bundle_id.is_a?(String) && bundle_id.match?(ASCReviewStatus::BUNDLE_ID_PATTERN)
        raise ASCStatusError, "IOS_BUNDLE_ID is invalid"
      end
      unless marketing_version.is_a?(String) && marketing_version.bytesize <= 32 &&
             marketing_version.match?(ASCReviewStatus::VERSION_PATTERN)
        raise ASCStatusError, "review notes requires an exact marketing version"
      end

      result = {
        "schema_version" => 1, "checked_at" => checked_at.utc.iso8601,
        "app" => { "id" => nil, "bundle_id" => bundle_id },
        "version" => { "id" => nil, "version_string" => marketing_version, "platform" => "IOS" },
        "review_notes" => notes_result("unavailable"), "complete" => false, "errors" => []
      }
      scope = "app"
      apps = client.paginate("/v1/apps", {
        "filter[bundleId]" => bundle_id, "fields[apps]" => "bundleId", "limit" => "2"
      })
      unless apps.is_a?(Array) && apps.length == 1 && resource?(apps.first, "apps") &&
             apps.first["id"].match?(APP_ID) && apps.first.dig("attributes", "bundleId") == bundle_id
        return failure(result, scope, "identity_unverified")
      end
      app_id = apps.first.fetch("id")
      result["app"]["id"] = app_id

      scope = "version"
      versions = client.paginate("/v1/apps/#{app_id}/appStoreVersions", {
        "filter[platform]" => "IOS", "filter[versionString]" => marketing_version,
        "fields[appStoreVersions]" => "platform,versionString", "limit" => "200"
      })
      unless versions.is_a?(Array) && versions.length == 1 && resource?(versions.first, "appStoreVersions") &&
             versions.first.dig("attributes", "platform") == "IOS" &&
             versions.first.dig("attributes", "versionString") == marketing_version &&
             app_scoped?(versions.first, app_id)
        return failure(result, scope, "exact_ios_version_unverified")
      end
      version_id = versions.first.fetch("id")
      result["version"]["id"] = version_id

      scope = "review_notes"
      document = client.get("/v1/appStoreVersions/#{version_id}/appStoreReviewDetail", {
        "fields[appStoreReviewDetails]" => "notes"
      })
      unless document.is_a?(Hash) && document.key?("data")
        return failure(result, scope, "invalid_detail_response")
      end
      detail = document["data"]
      if detail.nil?
        result["review_notes"] = notes_result("absent")
      elsif resource?(detail, "appStoreReviewDetails") && version_scoped?(detail, version_id) &&
            detail.fetch("attributes").key?("notes")
        notes = detail.fetch("attributes").fetch("notes")
        unless notes.nil? || (notes.is_a?(String) && notes.valid_encoding?)
          return failure(result, scope, "invalid_notes_field")
        end
        result["review_notes"] = notes_result(notes.nil? ? "null" : "present", notes)
      else
        return failure(result, scope, "unverified_detail_or_missing_notes")
      end
      result["complete"] = true
      result
    rescue ASCPermissionError
      raise unless result

      failure(result, scope, "permission_denied")
    rescue ASCStatusError
      raise unless result

      failure(result, scope, "request_failed")
    end

    def notes_result(observation, notes = nil)
      {
        "observation" => observation, "notes" => notes,
        "sha256" => notes.nil? ? nil : Digest::SHA256.hexdigest(notes),
        "length" => notes&.length, "byte_length" => notes&.bytesize
      }
    end
    private_class_method :notes_result

    def failure(result, scope, code)
      # Error responses intentionally exclude remote messages and private detail fields.
      result.fetch("errors") << { "scope" => scope, "code" => code }
      result
    end
    private_class_method :failure

    def resource?(resource, type)
      resource.is_a?(Hash) && resource["type"] == type && resource["id"].is_a?(String) &&
        resource["id"].match?(RESOURCE_ID) && resource["attributes"].is_a?(Hash)
    end
    private_class_method :resource?

    def app_scoped?(version, app_id)
      optional_relation_matches?(version, "app", "apps", app_id)
    end
    private_class_method :app_scoped?

    def version_scoped?(detail, version_id)
      optional_relation_matches?(detail, "appStoreVersion", "appStoreVersions", version_id)
    end
    private_class_method :version_scoped?

    def optional_relation_matches?(resource, name, type, id)
      relationships = resource["relationships"]
      return true if relationships.nil?
      return false unless relationships.is_a?(Hash)
      return true unless relationships.key?(name)

      relationship = relationships[name]
      return false unless relationship.is_a?(Hash)
      # Parent app/version-scoped endpoints already establish identity when optional linkage is omitted.
      return true unless relationship.key?("data")

      link = relationship["data"]
      link.is_a?(Hash) && link["type"] == type && link["id"] == id
    end
    private_class_method :optional_relation_matches?
  end
end
