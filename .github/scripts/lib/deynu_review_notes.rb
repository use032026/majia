# frozen_string_literal: true

require "digest"
require_relative "asc_review_status"

module MajiaCI
  class DeynuReviewNotesError < StandardError
    attr_reader :code
    def initialize(code)
      @code = code
      super(code)
    end
  end

  # Dedicated transport: no implicit HTTP retries for either verb. Only GET is
  # explicitly retried, at most three times. PATCH is always exactly one attempt.
  class DeynuReviewNotesClient < ASCClient
    GET_ATTEMPTS = 3

    def get(path, query = nil)
      attempts = 0
      begin
        attempts += 1
        request_document(:get, path, query: query, expected_status: 200)
      rescue StandardError
        retry if attempts < GET_ATTEMPTS
        raise DeynuReviewNotesError, "read_unavailable"
      end
    end

    def patch(path, payload)
      request_document(:patch, path, payload: payload, expected_status: 200)
    rescue StandardError
      raise DeynuReviewNotesError, "patch_unconfirmed"
    end
  end

  module DeynuReviewNotes
    module_function

    APP_ID = "6824457290"
    BUNDLE_ID = "com.almanac.lite"
    VERSION = "1.0.11"
    BUILD_NUMBER = "1"
    BUILD_ID = "130d4983-6020-41a3-a25a-f45dce28cfee"
    # Local evidence binding, NOT a field obtained from App Store Connect.
    SOURCE_COMMIT = "4983b26eed8bbfc312491e5d293a7b310717a3b6"
    IPA_SHA256 = "151b0ddde7f1cabf15a850165572fc5b3bb31a6a66bc11124ace585e72c262e4"
    # Conservative local bounds, not a claim about Apple's update schema limits.
    MAX_NOTES_BYTES = 16_000
    MAX_DESIRED_CHARACTERS = 4000
    HASH_ALGORITHM = "sha256 of UTF-8 JSON.generate(notes); null/string distinct; no normalization"
    UUID = /\A[0-9a-f]{8}(?:-[0-9a-f]{4}){3}-[0-9a-f]{12}\z/
    HASH = /\A[0-9a-f]{64}\z/
    VERSION_FIELDS = { "fields[appStoreVersions]" => "platform,versionString,appVersionState,releaseType" }.freeze
    NOTES_FIELDS = { "fields[appStoreReviewDetails]" => "notes" }.freeze
    SAFE_ERRORS = %w[
      invalid_inputs invalid_desired_notes invalid_current_notes missing_notes_field
      app_identity_mismatch version_not_unique version_identity_mismatch version_not_editable
      build_identity_mismatch build_not_valid_unexpired detail_missing detail_identity_mismatch
      expected_hash_required current_hash_mismatch prewrite_identity_changed prewrite_notes_changed
      read_unavailable patch_unconfirmed patch_response_ambiguous post_read_failed post_read_mismatch
      unexpected_failure configuration_or_evidence_io_failed
    ].freeze

    def failure(code = "unexpected_failure")
      base_summary.merge("status" => "failed", "error_code" => SAFE_ERRORS.include?(code) ? code : "unexpected_failure")
    end

    def base_summary
      {
        "schema_version" => 1,
        "app" => { "id" => APP_ID, "bundle_id" => BUNDLE_ID },
        "version" => { "version_string" => VERSION, "platform" => "IOS" },
        "build" => { "id" => BUILD_ID, "version" => BUILD_NUMBER },
        "local_signed_evidence" => { "source_commit" => SOURCE_COMMIT, "ipa_sha256" => IPA_SHA256 },
        "notes_hash_algorithm" => HASH_ALGORITHM,
        "concurrency_boundary" => "Expected hash is a best-effort precondition, not an atomic ASC compare-and-swap.",
        "apply_requested" => false, "write_attempted" => false, "may_have_written" => false,
        "patch_accepted" => false, "verified" => false, "no_op" => false, "status" => "read_only"
      }
    end

    def notes_hash(notes)
      Digest::SHA256.hexdigest(JSON.generate(notes).encode(Encoding::UTF_8))
    end

    def sync(client:, marketing_version:, build_number:, expected_build_id:, apply: false,
             desired_notes: nil, expected_current_hash: nil)
      summary = base_summary
      guard([true, false].include?(apply) && marketing_version == VERSION &&
            build_number == BUILD_NUMBER && expected_build_id == BUILD_ID, "invalid_inputs")
      summary["apply_requested"] = apply
      unless desired_notes.nil?
        validate_notes(desired_notes, desired: true, nonempty: apply)
        summary["desired_notes_hash"] = notes_hash(desired_notes)
        summary["desired_notes_state"] = notes_state(desired_notes)
      end
      guard(!desired_notes.nil?, "invalid_desired_notes") if apply
      if apply
        guard(expected_current_hash.is_a?(String) && expected_current_hash.match?(HASH), "expected_hash_required")
      elsif !expected_current_hash.nil? && expected_current_hash != ""
        guard(expected_current_hash.is_a?(String) && expected_current_hash.match?(HASH), "expected_hash_required")
      end

      before = snapshot(client)
      summarize_snapshot(summary, before)
      summary["matches_desired"] = desired_notes.nil? ? nil : before[:notes] == desired_notes
      if expected_current_hash && !expected_current_hash.empty?
        guard(summary["current_notes_hash"] == expected_current_hash, "current_hash_mismatch")
      end
      return summary unless apply
      if before[:notes] == desired_notes
        summary.merge!("status" => "unchanged", "no_op" => true, "verified" => true)
        return summary
      end

      # Re-read every identity/state/binding/detail immediately before the one
      # write. This reduces drift; ASC does not offer a proven atomic CAS here.
      fresh = snapshot(client)
      guard(before[:version_id] == fresh[:version_id] && before[:detail_id] == fresh[:detail_id], "prewrite_identity_changed")
      guard(notes_hash(fresh[:notes]) == expected_current_hash, "prewrite_notes_changed")
      path = "/v1/appStoreReviewDetails/#{fresh[:detail_id]}"
      payload = { "data" => { "type" => "appStoreReviewDetails", "id" => fresh[:detail_id],
                              "attributes" => { "notes" => desired_notes } } }
      summary["write_attempted"] = true
      summary["may_have_written"] = true
      patch_error = nil
      begin
        response = client.patch(path, payload)
        data = response.is_a?(Hash) ? response["data"] : nil
        if resource?(data, "appStoreReviewDetails", fresh[:detail_id])
          summary["patch_accepted"] = true
        else
          patch_error = "patch_response_ambiguous"
        end
      rescue StandardError
        patch_error = "patch_unconfirmed"
      end
      begin
        after = detail_notes(client.get(path, NOTES_FIELDS), expected_id: fresh[:detail_id])
        summary["after_notes_hash"] = notes_hash(after[:notes])
        summary["post_read_matches_desired"] = after[:notes] == desired_notes
      rescue StandardError
        summary["post_read_matches_desired"] = false
        patch_error ||= "post_read_failed"
      end
      patch_error ||= "post_read_mismatch" unless summary["post_read_matches_desired"]
      if patch_error
        summary.merge!("status" => "failed", "error_code" => patch_error)
      else
        summary.merge!("status" => "written_and_verified", "verified" => true)
      end
      summary
    rescue StandardError, Interrupt, SystemExit => error
      code = error.is_a?(DeynuReviewNotesError) && SAFE_ERRORS.include?(error.code) ? error.code : "unexpected_failure"
      summary.merge("status" => "failed", "error_code" => code)
    end

    def guard(condition, code)
      raise DeynuReviewNotesError, code unless condition
    end
    private_class_method :guard

    def validate_notes(value, desired:, nonempty: false)
      code = desired ? "invalid_desired_notes" : "invalid_current_notes"
      guard(value.is_a?(String), code)
      guard(value.encoding == Encoding::UTF_8 || value.ascii_only?, code)
      guard(value.valid_encoding? && value.bytesize <= MAX_NOTES_BYTES, code)
      guard(!value.match?(/[\u0000-\u0008\u000B\u000C\u000E-\u001F\u007F]/), code)
      guard(value.length <= MAX_DESIRED_CHARACTERS, code) if desired
      guard(!value.strip.empty?, code) if nonempty
    end
    private_class_method :validate_notes

    def notes_state(value)
      value.nil? ? "null" : value.empty? ? "empty_string" : "string"
    end
    private_class_method :notes_state

    def resource?(data, type, id = nil)
      data.is_a?(Hash) && data["type"] == type && data["id"].is_a?(String) &&
        data["id"].match?(UUID) && (id.nil? || data["id"] == id)
    end
    private_class_method :resource?

    def snapshot(client)
      app_document = client.get("/v1/apps/#{APP_ID}", { "fields[apps]" => "bundleId" })
      app = app_document.is_a?(Hash) ? app_document["data"] : nil
      guard(app.is_a?(Hash) && app["type"] == "apps" && app["id"] == APP_ID &&
            app.dig("attributes", "bundleId") == BUNDLE_ID, "app_identity_mismatch")
      versions_document = client.get("/v1/apps/#{APP_ID}/appStoreVersions", VERSION_FIELDS.merge(
        "filter[platform]" => "IOS", "filter[versionString]" => VERSION, "limit" => "2"
      ))
      versions = versions_document.is_a?(Hash) ? versions_document["data"] : nil
      next_page = versions_document.is_a?(Hash) ? versions_document.dig("links", "next") : nil
      guard(versions.is_a?(Array) && versions.length == 1 && (next_page.nil? || next_page == ""), "version_not_unique")
      version = versions.first
      guard(resource?(version, "appStoreVersions") && version.dig("attributes", "platform") == "IOS" &&
            version.dig("attributes", "versionString") == VERSION, "version_identity_mismatch")
      guard(version.dig("attributes", "appVersionState") == "PREPARE_FOR_SUBMISSION" &&
            version.dig("attributes", "releaseType") == "AFTER_APPROVAL", "version_not_editable")
      version_id = version.fetch("id")
      build_document = client.get("/v1/appStoreVersions/#{version_id}/build", {
        "fields[builds]" => "version,processingState,expired"
      })
      build = build_document.is_a?(Hash) ? build_document["data"] : nil
      guard(resource?(build, "builds", BUILD_ID) && build.dig("attributes", "version") == BUILD_NUMBER, "build_identity_mismatch")
      guard(build.dig("attributes", "processingState") == "VALID" &&
            build.dig("attributes", "expired") == false, "build_not_valid_unexpired")
      detail = detail_notes(client.get("/v1/appStoreVersions/#{version_id}/appStoreReviewDetail", NOTES_FIELDS))
      detail.merge(version_id: version_id)
    end
    private_class_method :snapshot

    def detail_notes(document, expected_id: nil)
      data = document.is_a?(Hash) ? document["data"] : nil
      guard(!data.nil?, "detail_missing")
      guard(resource?(data, "appStoreReviewDetails", expected_id), "detail_identity_mismatch")
      attributes = data["attributes"]
      guard(attributes.is_a?(Hash) && attributes.key?("notes"), "missing_notes_field")
      notes = attributes["notes"]
      validate_notes(notes, desired: false) unless notes.nil?
      { detail_id: data.fetch("id"), notes: notes }
    end
    private_class_method :detail_notes

    def summarize_snapshot(summary, snapshot)
      summary["version"]["id"] = snapshot[:version_id]
      summary["version"].merge!("app_version_state" => "PREPARE_FOR_SUBMISSION", "release_type" => "AFTER_APPROVAL")
      summary["build"].merge!("processing_state" => "VALID", "expired" => false)
      summary["detail_id"] = snapshot[:detail_id]
      summary["current_notes_state"] = notes_state(snapshot[:notes])
      summary["current_notes_hash"] = notes_hash(snapshot[:notes])
    end
    private_class_method :summarize_snapshot
  end
end
