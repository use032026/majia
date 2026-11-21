# frozen_string_literal: true

require "cgi"
require "json"
require "date"

module MajiaCI
  # Presentation only: no client, environment, network, or write operations.
  module ASCReadonlySummary
    module_function

    UNAVAILABLE = "not observed or invalid"
    MAX_ROWS = 500
    MAX_WHATS_NEW = 4_000
    ID = /\A(?:[0-9]{1,20}|[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12})\z/
    VERSION = /\A[0-9]{1,10}(?:\.[0-9]{1,10}){0,2}\z/
    BUNDLE = /\A[A-Za-z0-9-]+(?:\.[A-Za-z0-9-]+)+\z/
    LOCALE = /\A[a-z]{2,3}(?:-[A-Z][a-z]{3})?(?:-[A-Z]{2}|-[0-9]{3})?\z/
    STATES = %w[
      PREPARE_FOR_SUBMISSION READY_FOR_REVIEW WAITING_FOR_REVIEW IN_REVIEW ACCEPTED
      PENDING_APPLE_RELEASE PENDING_CONTRACT PENDING_DEVELOPER_RELEASE PROCESSING_FOR_APP_STORE
      PROCESSING_FOR_DISTRIBUTION READY_FOR_SALE READY_FOR_DISTRIBUTION PREORDER_READY_FOR_SALE
      REJECTED METADATA_REJECTED INVALID_BINARY DEVELOPER_REJECTED WAITING_FOR_EXPORT_COMPLIANCE
      DEVELOPER_REMOVED_FROM_SALE REMOVED_FROM_SALE REPLACED_WITH_NEW_VERSION
      UNRESOLVED_ISSUES CANCELING CANCELED COMPLETING COMPLETE PROCESSING FAILED VALID INVALID
      AWAITING_UPLOAD UPLOAD_COMPLETE UPLOADING SUBMITTED_FOR_REVIEW REMOVED
    ].freeze
    RELEASE_TYPES = %w[AFTER_APPROVAL MANUAL SCHEDULED].freeze

    def markdown(mode, input)
      value = input.is_a?(Hash) ? input : {}
      safe = case mode
             when :inventory then inventory(value)
             when :metadata then metadata(value)
             when :diagnostics then diagnostics(value)
             when :history then history(value)
             when :review_notes then review_notes(value)
             when :status then status(value)
             else raise ArgumentError, "unsupported ASC summary mode"
             end
      safe = { "checked_at" => utc_timestamp(value["checked_at"]) }.merge(safe)
      title = { inventory: "build inventory", metadata: "store metadata", diagnostics: "review diagnostics", history: "review history lower bound", review_notes: "review notes fingerprint", status: "review status" }.fetch(mode)
      "## ASC #{title}\n\nRead-only observed fields; unavailable or truncated data is not complete evidence.\n\n<pre>#{CGI.escapeHTML(JSON.pretty_generate(safe))}</pre>\n"
    end

    def utc_timestamp(value)
      return UNAVAILABLE unless value.is_a?(String) && value.valid_encoding? && value.match?(/\A[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}:[0-9]{2}Z\z/)

      DateTime.iso8601(value).strftime("%Y-%m-%dT%H:%M:%SZ") == value ? value : UNAVAILABLE
    rescue Date::Error
      UNAVAILABLE
    end

    def inventory(value)
      {
        "app" => app(value["app"]),
        "marketing_version" => field(value["marketing_version"], VERSION),
        "build_uploads" => rows(value["build_uploads"]) do |row|
          { "id" => field(row["id"], ID), "number" => field(row["version"], VERSION), "state" => state(row["state"]) }
        end,
        "prerelease_builds" => rows(value["prerelease_builds"]) { |row| build(row, raw: false) },
        "visibility_boundary" => "Empty observed inventory does not rule out uploads not yet visible to ASC."
      }
    end

    def metadata(value)
      version = hash(value["version"])
      attrs = hash(version["attributes"])
      errors = value["errors"]
      {
        "app" => app(value["app"], raw: true),
        "version" => {
          "id" => field(version["id"], ID),
          "number" => field(attrs["versionString"], VERSION),
          "state" => state(attrs["appVersionState"]),
          "release_type" => member(attrs["releaseType"], RELEASE_TYPES)
        },
        "bound_build" => build(value["build"], raw: true),
        "query_errors_present" => errors.is_a?(Array) ? !errors.empty? : UNAVAILABLE,
        "localizations" => rows(value["localizations"]) do |row|
          attributes = hash(row["attributes"])
          locale = field(attributes["locale"], LOCALE)
          {
            "locale" => locale,
            "whats_new" => locale == UNAVAILABLE ? UNAVAILABLE : public_text(attributes["whatsNew"])
          }
        end
      }
    end

    def diagnostics(value)
      section = hash(hash(value["sections"])["review_drafts"])
      {
        "app" => app(value["app"]),
        "version" => version_identity(value["version"], "marketing_version", "state"),
        "review_drafts_observation" => member(section["status"], %w[observed absent unavailable permission_denied]),
        "target_submissions" => rows(section["target_submissions"]) { |row| submission(row) },
        "observed_submissions" => rows(section["observed_submissions"]) { |row| submission(row) }
      }
    end

    def review_notes(value)
      notes = hash(value["review_notes"])
      version = hash(value["version"])
      {
        "app" => app(value["app"]),
        "version" => { "id" => field(version["id"], ID), "number" => field(version["version_string"], VERSION) },
        "complete" => boolean(value["complete"]),
        "review_notes" => {
          "observation" => member(notes["observation"], %w[present null absent unavailable]),
          "sha256" => field(notes["sha256"], /\A[0-9a-f]{64}\z/),
          "length" => nonnegative_integer(notes["length"]),
          "byte_length" => nonnegative_integer(notes["byte_length"])
        },
        "query_errors_present" => value["errors"].is_a?(Array) ? !value["errors"].empty? : UNAVAILABLE,
        "content_boundary" => "Review notes content is omitted from logs and summaries; inspect only the protected raw artifact."
      }
    end

    def history(value)
      decision = hash(value["decision"])
      {
        "app" => app(value["app"]),
        "count_scope" => member(value["count_scope"], ["CURRENT_OBSERVABLE_RECORDS"]),
        "confirmed_distinct_submitted_lower_bound" => nonnegative_integer(value["confirmed_distinct_submitted_lower_bound"]),
        "api_scan_complete" => boolean(value["api_scan_complete"]),
        "history_complete" => boolean(value["history_complete"]),
        "decision" => {
          "label" => member(decision["label"], ["可使用", "不可使用", "待核实"]),
          "stop_auto_submission" => boolean(decision["stop_auto_submission"])
        },
        "distinct_versions" => rows(value["distinct_versions"]) do |row|
          {
            "marketing_version" => field(row["marketing_version"], VERSION),
            "version_ids" => safe_members(row["version_ids"]) { |id| field(id, ID) },
            "app_version_states" => safe_members(row["app_version_states"]) { |item| state(item) }
          }
        end,
        "query_errors_present" => value["errors"].is_a?(Array) ? !value["errors"].empty? : UNAVAILABLE,
        "unknowns_present" => value["unknowns"].is_a?(Array) ? !value["unknowns"].empty? : UNAVAILABLE,
        "history_boundary" => "Only a proven lower bound. A complete current API scan does not establish complete lifetime submission history."
      }
    end

    def nonnegative_integer(value)
      value.is_a?(Integer) && value.between?(0, 1_000_000) ? value : UNAVAILABLE
    end

    def safe_members(value)
      return UNAVAILABLE unless value.is_a?(Array)

      value.first(MAX_ROWS).map { |item| yield(item) }
    end

    def status(value)
      version = hash(value["version"])
      {
        "app" => app(value["app"]),
        "version" => version_identity(version, "version_string", "app_version_state").merge(
          "release_type" => member(version["release_type"], RELEASE_TYPES)
        ),
        "bound_build" => build(value["build"], raw: false),
        "review_submission" => submission(value["review_submission"]),
        "review_submission_query_unavailable" => value.key?("review_submission_query_error") ? !value["review_submission_query_error"].nil? : UNAVAILABLE
      }
    end

    def app(value, raw: false)
      row = hash(value)
      bundle = raw ? hash(row["attributes"])["bundleId"] : row["bundle_id"]
      { "id" => field(row["id"], ID), "bundle_id" => field(bundle, BUNDLE, max: 255) }
    end

    def version_identity(value, number_key, state_key)
      row = hash(value)
      { "id" => field(row["id"], ID), "number" => field(row[number_key], VERSION), "state" => state(row[state_key]) }
    end

    def build(value, raw:)
      row = hash(value)
      attrs = raw ? hash(row["attributes"]) : row
      {
        "id" => field(row["id"], ID),
        "number" => field(attrs["version"], VERSION),
        "processing_state" => state(attrs[raw ? "processingState" : "processing_state"]),
        "expired" => boolean(attrs["expired"])
      }
    end

    def submission(value)
      row = hash(value)
      { "id" => field(row["id"], ID), "state" => state(row["state"]) }
    end

    def rows(value)
      return { "observation" => UNAVAILABLE } unless value.is_a?(Array)

      {
        "observation" => "observed", "observed_count" => value.length,
        "truncated" => value.length > MAX_ROWS,
        "items" => value.first(MAX_ROWS).map { |row| yield(hash(row)) }
      }
    end

    def public_text(value)
      return UNAVAILABLE unless value.is_a?(String) && value.valid_encoding?

      { "text" => value[0, MAX_WHATS_NEW], "truncated" => value.length > MAX_WHATS_NEW }
    end

    def field(value, pattern, max: 100)
      value.is_a?(String) && value.valid_encoding? && value.length <= max && pattern.match?(value) ? value : UNAVAILABLE
    end

    def state(value)
      member(value, STATES)
    end

    def member(value, allowed)
      allowed.include?(value) ? value : UNAVAILABLE
    end

    def boolean(value)
      value == true || value == false ? value : UNAVAILABLE
    end

    def hash(value)
      value.is_a?(Hash) ? value : {}
    end
  end
end
