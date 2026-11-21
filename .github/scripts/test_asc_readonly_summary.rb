# frozen_string_literal: true

require "json"
require "cgi"
require "minitest/autorun"
require "tmpdir"
require_relative "lib/asc_readonly_summary"
require_relative "query-asc-store-metadata"

class ASCReadonlySummaryTest < Minitest::Test
  Summary = MajiaCI::ASCReadonlySummary
  AppID = "6822704143"
  VersionID = "7bbae275-c2da-4caf-942a-f8f35277f8cc"
  BuildID = "32bf7b05-f4db-4c68-8e7e-2990c1e36f61"
  SubmissionID = "a27aa713-b7a4-4c08-8c56-72a331ecdf20"
  Secret = "SECRET_CANARY_DO_NOT_SHOW"

  def test_review_notes_summary_only_contains_fingerprint_and_not_content_or_contacts
    canary = "PRIVATE_NOTES_CANARY<script>secret</script>"
    payload = {
      "checked_at" => "2026-11-21T09:00:00Z", "complete" => true,
      "app" => { "id" => "6822704143", "bundle_id" => "com.tripdelta.lite.app", "contact" => canary },
      "version" => { "id" => "f991521a-405e-4422-be57-6f1dec949af2", "version_string" => "1.0.10" },
      "review_notes" => { "observation" => "present", "notes" => canary, "sha256" => "a" * 64, "length" => 45, "byte_length" => 45 },
      "errors" => [{ "raw" => canary }], "demoAccountPassword" => canary
    }
    result = Summary.markdown(:review_notes, payload)
    assert_includes result, "a" * 64
    assert_includes result, "present"
    refute_includes result, canary
    refute_includes result, "PRIVATE_NOTES_CANARY"
    refute_includes result, "demoAccountPassword"
    refute_includes result, "contact"
    %i[status inventory metadata history diagnostics].each do |mode|
      refute_includes Summary.markdown(mode, payload), "PRIVATE_NOTES_CANARY"
    end
  end

  def test_history_keeps_lower_bound_and_lifetime_uncertainty_separate
    value = {
      "app" => inventory["app"], "confirmed_distinct_submitted_lower_bound" => 8,
      "api_scan_complete" => true, "history_complete" => false,
      "decision" => { "label" => "待核实", "stop_auto_submission" => nil },
      "distinct_versions" => [{ "marketing_version" => "1.0", "version_ids" => [VersionID],
        "app_version_states" => ["DEVELOPER_REJECTED"], "evidence" => [{ "notes" => Secret }] }],
      "errors" => [], "unknowns" => [{ "detail" => Secret }], "private_key" => Secret
    }
    result = parsed(:history, value)
    assert_equal 8, result["confirmed_distinct_submitted_lower_bound"]
    assert_equal true, result["api_scan_complete"]
    assert_equal false, result["history_complete"]
    assert_equal "待核实", result.dig("decision", "label")
    assert_equal Summary::UNAVAILABLE, result.dig("decision", "stop_auto_submission")
    assert_equal "1.0", result.dig("distinct_versions", "items", 0, "marketing_version")
    assert_equal true, result["unknowns_present"]
    refute_includes Summary.markdown(:history, value), Secret
  end

  def test_history_summary_filters_remote_text_and_invalid_counters
    attack = "</pre><script>#{Secret}</script>"
    value = {
      "app" => { "id" => attack, "bundle_id" => attack },
      "confirmed_distinct_submitted_lower_bound" => attack,
      "api_scan_complete" => attack, "history_complete" => nil,
      "decision" => { "label" => attack, "stop_auto_submission" => attack },
      "distinct_versions" => [{ "marketing_version" => attack, "version_ids" => [attack], "app_version_states" => [attack] }],
      "errors" => [{ "message" => attack }], "unknowns" => []
    }
    result = parsed(:history, value)
    assert_equal Summary::UNAVAILABLE, result["confirmed_distinct_submitted_lower_bound"]
    assert_equal true, result["query_errors_present"]
    html = Summary.markdown(:history, value)
    refute_includes html, Secret
    assert_equal 1, html.scan("<pre>").length
    assert_equal 1, html.scan("</pre>").length
  end

  def parsed(mode, value)
    text = Summary.markdown(mode, value)
    JSON.parse(CGI.unescapeHTML(text.split("<pre>", 2).last.split("</pre>", 2).first))
  end

  def test_real_inventory_schema_keeps_identity_and_exact_build_evidence
    result = parsed(:inventory, inventory)
    assert_equal({ "id" => AppID, "bundle_id" => "com.tripdelta.lite.app" }, result["app"])
    assert_equal "1.0.8", result["marketing_version"]
    assert_equal [{ "id" => BuildID, "number" => "2", "state" => "COMPLETE" }], result.dig("build_uploads", "items")
    assert_equal [{ "id" => BuildID, "number" => "2", "processing_state" => "VALID", "expired" => false }], result.dig("prerelease_builds", "items")
    refute_includes Summary.markdown(:inventory, inventory), Secret
  end

  def test_metadata_schema_exposes_only_bound_build_release_and_public_whats_new
    result = parsed(:metadata, metadata)
    assert_equal AppID, result.dig("app", "id")
    assert_equal VersionID, result.dig("version", "id")
    assert_equal "AFTER_APPROVAL", result.dig("version", "release_type")
    assert_equal BuildID, result.dig("bound_build", "id")
    assert_equal false, result.dig("bound_build", "expired")
    assert_equal false, result["query_errors_present"]
    assert_equal({ "locale" => "en-US", "whats_new" => { "text" => "Improved reliability.", "truncated" => false } }, result.dig("localizations", "items", 0))
    refute_includes Summary.markdown(:metadata, metadata), Secret
  end

  def test_html_markdown_and_newline_payload_remains_inside_escaped_pre
    value = metadata
    attack = "</pre><script>alert(1)</script>\n# forged result\n[link](https://example.invalid/)\n&"
    value["localizations"][0]["attributes"]["whatsNew"] = attack
    html = Summary.markdown(:metadata, value)
    assert_equal 1, html.scan("<pre>").length
    assert_equal 1, html.scan("</pre>").length
    refute_includes html, "<script>"
    assert_includes html, "&lt;/pre&gt;&lt;script&gt;"
    assert_equal attack, parsed(:metadata, value).dig("localizations", "items", 0, "whats_new", "text")
  end

  def test_missing_rows_and_boolean_are_not_reported_as_empty_complete_evidence
    result = parsed(:inventory, {})
    assert_equal Summary::UNAVAILABLE, result.dig("build_uploads", "observation")
    assert_equal Summary::UNAVAILABLE, result.dig("prerelease_builds", "observation")
    assert_equal Summary::UNAVAILABLE, parsed(:metadata, {}).dig("bound_build", "expired")
    observed = parsed(:inventory, inventory.merge("build_uploads" => []))
    assert_equal "observed", observed.dig("build_uploads", "observation")
    assert_equal 0, observed.dig("build_uploads", "observed_count")
    assert_match(/not yet visible/, observed["visibility_boundary"])
  end

  def test_invalid_ids_locales_states_and_secret_fields_are_not_rendered
    value = metadata
    value["app"]["id"] = Secret
    value["version"]["id"] = "https://example.invalid/#{Secret}"
    value["version"]["attributes"]["appVersionState"] = Secret
    value["localizations"][0]["attributes"]["locale"] = "en-US\n#{Secret}"
    html = Summary.markdown(:metadata, value)
    refute_includes html, Secret
    refute_includes html, "https://example.invalid"
    result = parsed(:metadata, value)
    assert_equal Summary::UNAVAILABLE, result.dig("app", "id")
    assert_equal Summary::UNAVAILABLE, result.dig("version", "state")
    assert_equal Summary::UNAVAILABLE, result.dig("localizations", "items", 0, "locale")
    assert_equal Summary::UNAVAILABLE, result.dig("localizations", "items", 0, "whats_new")
  end

  def test_whats_new_and_row_limit_have_explicit_truncation_markers
    value = metadata
    value["localizations"][0]["attributes"]["whatsNew"] = "x" * (Summary::MAX_WHATS_NEW + 1)
    text = parsed(:metadata, value).dig("localizations", "items", 0, "whats_new")
    assert_equal true, text["truncated"]
    assert_equal Summary::MAX_WHATS_NEW, text["text"].length
    value = inventory
    value["build_uploads"] *= Summary::MAX_ROWS + 1
    rows = parsed(:inventory, value)["build_uploads"]
    assert_equal Summary::MAX_ROWS + 1, rows["observed_count"]
    assert_equal Summary::MAX_ROWS, rows["items"].length
    assert_equal true, rows["truncated"]
  end

  def test_diagnostics_only_renders_observed_submission_ids_and_states
    value = {
      "app" => inventory["app"],
      "version" => { "id" => VersionID, "marketing_version" => "1.0.8", "state" => "READY_FOR_REVIEW" },
      "sections" => {
        "review_contact" => { "notes" => Secret, "demoAccountPassword" => Secret },
        "review_drafts" => { "status" => "observed", "target_submissions" => [{ "id" => SubmissionID, "state" => "CANCELED", "notes" => Secret }],
          "observed_submissions" => [{ "id" => SubmissionID, "state" => "CANCELED" }] }
      }, "errors" => Secret
    }
    result = parsed(:diagnostics, value)
    assert_equal [{ "id" => SubmissionID, "state" => "CANCELED" }], result.dig("target_submissions", "items")
    assert_equal [{ "id" => SubmissionID, "state" => "CANCELED" }], result.dig("observed_submissions", "items")
    refute_includes Summary.markdown(:diagnostics, value), Secret
    refute_includes Summary.markdown(:diagnostics, value), "review_contact"
  end

  def test_status_has_resource_ids_without_private_errors_or_app_name
    value = {
      "app" => inventory["app"].merge("name" => Secret),
      "version" => { "id" => VersionID, "version_string" => "1.0.8", "app_version_state" => "WAITING_FOR_REVIEW", "release_type" => "AFTER_APPROVAL" },
      "build" => inventory["prerelease_builds"].first,
      "review_submission" => { "id" => SubmissionID, "state" => "WAITING_FOR_REVIEW", "notes" => Secret },
      "review_submission_query_error" => Secret
    }
    result = parsed(:status, value)
    assert_equal SubmissionID, result.dig("review_submission", "id")
    assert_equal true, result["review_submission_query_unavailable"]
    refute_includes Summary.markdown(:status, value), Secret
  end

  def test_optional_metadata_summary_preserves_artifact_and_query_exit_status
    Dir.mktmpdir("asc-safe-summary") do |dir|
      [false, true].each do |query_error|
        result = metadata
        result["errors"] = [{ "error" => Secret }] if query_error
        output = File.join(dir, "snapshot.json")
        summary = File.join(dir, "summary.md")
        old_env = %w[ASC_KEY_ID ASC_ISSUER_ID ASC_API_KEY_P8].to_h { |key| [key, ENV[key]] }
        ENV["ASC_KEY_ID"] = "ABC123DEFG"
        ENV["ASC_ISSUER_ID"] = VersionID
        ENV["ASC_API_KEY_P8"] = Secret
        status = nil
        capture_io do
          with_stub(MajiaCI::ASCReviewStatus, :normalize_private_key, :test_key) do
            with_stub(MajiaCI::ASCReadClient, :new, Object.new) do
              with_stub(MajiaCI::ASCStoreMetadata, :read, result) do
                status = MajiaCI::ASCStoreMetadata.main([
                  "--bundle-id", "com.tripdelta.lite.app", "--marketing-version", "1.0.8",
                  "--output", output, "--github-summary", summary
                ])
              end
            end
          end
        end
        assert_equal query_error ? 1 : 0, status
        assert_equal result, JSON.parse(File.read(output))
        refute_includes File.read(summary), Secret
      ensure
        old_env&.each { |key, old| old.nil? ? ENV.delete(key) : ENV[key] = old }
      end
    end
  end

  def test_actual_metadata_reader_remains_read_only_and_formats_its_schema
    sample = metadata
    client = Object.new
    calls = []
    client.define_singleton_method(:paginate) do |path, query = nil|
      calls << [:paginate, path, query]
      case path
      when "/v1/apps" then [sample["app"]]
      when "/v1/apps/#{AppID}/appStoreVersions" then [sample["version"]]
      else []
      end
    end
    client.define_singleton_method(:get) do |path, query = nil|
      calls << [:get, path, query]
      data = case path
             when "/v1/appStoreVersions/#{VersionID}" then sample["version"]
             when "/v1/appStoreVersions/#{VersionID}/relationships/build" then { "id" => BuildID }
             when "/v1/builds/#{BuildID}" then sample["build"]
             else raise "unexpected read endpoint"
             end
      { "data" => data }
    end
    %i[post patch post_created delete].each do |method|
      client.define_singleton_method(method) { |*args| raise "must remain read-only" }
    end
    sample["version"]["attributes"]["platform"] = "IOS"
    result = MajiaCI::ASCStoreMetadata.read(client: client, bundle_id: "com.tripdelta.lite.app", marketing_version: "1.0.8")
    assert_empty result["errors"]
    assert_equal BuildID, parsed(:metadata, result).dig("bound_build", "id")
    assert_equal "1.0.8", calls.find { |call| call[1].end_with?("/appStoreVersions") }[2]["filter[versionString]"]
    assert calls.all? { |call| %i[get paginate].include?(call[0]) }
  end

  def test_checked_at_is_exact_valid_utc_timestamp_only
    value = inventory.merge("checked_at" => "2026-11-19T10:20:30Z")
    assert_equal "2026-11-19T10:20:30Z", parsed(:inventory, value)["checked_at"]
    [Secret, "2026-02-31T10:20:30Z", "2026-11-19T10:20:30+08:00", nil].each do |invalid|
      assert_equal Summary::UNAVAILABLE, parsed(:inventory, value.merge("checked_at" => invalid))["checked_at"]
    end
  end

  def test_workflow_only_wires_existing_metadata_query_to_summary
    workflow = File.read(File.expand_path("../workflows/asc-review-status.yml", __dir__))
    assert_match(/--output asc-store-metadata.json \\\n\s+--github-summary "\$GITHUB_STEP_SUMMARY"/, workflow)
    formatter = File.read(File.join(__dir__, "lib/asc_readonly_summary.rb"))
    refute_match(/ENV\[|ENV\.fetch|client\.|Net::HTTP|File\.(?:write|open)/, formatter)
    assert_raises(ArgumentError) { Summary.markdown(:unrecognized, {}) }
  end

  private

  def with_stub(target, name, value)
    original = target.method(name)
    target.define_singleton_method(name) { |*args, **kwargs| value }
    yield
  ensure
    target.define_singleton_method(name, original)
  end

  def inventory
    {
      "app" => { "id" => AppID, "bundle_id" => "com.tripdelta.lite.app", "notes" => Secret },
      "marketing_version" => "1.0.8",
      "build_uploads" => [{ "id" => BuildID, "version" => "2", "state" => "COMPLETE", "errors" => Secret }],
      "prerelease_builds" => [{ "id" => BuildID, "version" => "2", "processing_state" => "VALID", "expired" => false, "token" => Secret }]
    }
  end

  def metadata
    {
      "app" => { "id" => AppID, "attributes" => { "bundleId" => "com.tripdelta.lite.app", "name" => Secret } },
      "version" => { "id" => VersionID, "attributes" => { "versionString" => "1.0.8", "appVersionState" => "READY_FOR_REVIEW", "releaseType" => "AFTER_APPROVAL", "reviewNotes" => Secret } },
      "build" => { "id" => BuildID, "attributes" => { "version" => "2", "processingState" => "VALID", "expired" => false } },
      "errors" => [],
      "app_infos" => [{ "contactEmail" => Secret }],
      "localizations" => [{ "attributes" => { "locale" => "en-US", "whatsNew" => "Improved reliability.", "description" => Secret, "supportUrl" => "https://private.invalid/#{Secret}" }, "media" => Secret }]
    }
  end
end
