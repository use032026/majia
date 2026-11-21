# frozen_string_literal: true

require "minitest/autorun"
require "tmpdir"
require "json"
require "open3"
require "rbconfig"
require "yaml"

class ASCReviewNotesCLITest < Minitest::Test
  CLI = File.expand_path("query-asc-review-status.rb", __dir__)
  ROOT = File.expand_path("../..", __dir__)
  CANARY = "REVIEW_NOTES_PRIVATE_CANARY"

  def test_raw_artifact_is_private_even_when_overwriting_and_summary_never_prints_notes
    with_cli do |args, env, output, summary, _marker|
      File.write(output, "old")
      File.chmod(0o644, output)
      stdout, stderr, status = Open3.capture3(env, *args, "--review-notes", "--marketing-version", "1.0.10", unsetenv_others: true)
      assert status.success?, stderr
      assert_equal CANARY, JSON.parse(File.read(output)).dig("review_notes", "notes")
      assert_equal 0o600, File.stat(output).mode & 0o777
      assert_includes stdout, "protected artifact"
      assert_includes File.read(summary), "review notes fingerprint"
      refute_includes stdout + stderr + File.read(summary), CANARY
    end
  end

  def test_failed_note_observation_is_preserved_and_returns_nonzero
    with_cli(complete: false) do |args, env, output, summary, _marker|
      stdout, stderr, status = Open3.capture3(env, *args, "--review-notes", "--marketing-version", "1.0.10", unsetenv_others: true)
      refute status.success?
      assert_equal false, JSON.parse(File.read(output)).fetch("complete")
      refute_includes stdout + stderr + File.read(summary), CANARY
    end
  end

  def test_exact_version_and_mode_conflicts_fail_before_reading_p8
    [[], ["--marketing-version", "1.0.10", "--build-inventory"],
     ["--marketing-version", "1.0.10", "--review-diagnostics"],
     ["--marketing-version", "1.0.10", "--review-history"]].each do |extra|
      with_cli do |args, env, output, summary, marker|
        stdout, stderr, status = Open3.capture3(env, *args, "--review-notes", *extra, unsetenv_others: true)
        refute status.success?
        refute File.exist?(marker)
        refute File.exist?(output)
        refute File.exist?(summary)
        refute_includes stdout + stderr, CANARY
      end
    end
  end

  def test_manual_default_off_protected_exclusive_workflow_and_separate_artifact
    workflow = YAML.load_file(File.join(ROOT, ".github/workflows/asc-review-status.yml"))
    triggers = workflow.fetch("on") { workflow.fetch(true) }
    assert_equal ["workflow_dispatch"], triggers.keys
    input = triggers.fetch("workflow_dispatch").fetch("inputs").fetch("include_review_notes")
    assert_equal false, input.fetch("default")
    assert_equal "boolean", input.fetch("type")
    assert_equal({ "contents" => "read" }, workflow.fetch("permissions"))
    assert_equal "asc-review-status-${{ inputs.app_environment }}", workflow.fetch("concurrency").fetch("group")
    job = workflow.fetch("jobs").fetch("query")
    assert_equal "${{ inputs.app_environment }}", job.fetch("environment")
    steps = job.fetch("steps")
    notes = steps.find { |row| row["name"] == "Query read-only ASC review notes" }
    assert_equal "${{ inputs.include_review_notes }}", notes.fetch("if")
    assert_includes notes.fetch("run"), "--review-notes"
    assert_includes notes.fetch("run"), "-z"
    %w[MARKETING_VERSION INVENTORY_VERSION INCLUDE_STORE_METADATA INCLUDE_REVIEW_DIAGNOSTICS INCLUDE_REVIEW_HISTORY].each do |key|
      assert notes.fetch("env").key?(key)
      assert_includes notes.fetch("run"), key
    end
    steps.select { |step| step["name"].start_with?("Query read-only ASC") && step != notes }.each do |step|
      assert_includes step.fetch("if"), "!inputs.include_review_notes"
    end
    artifact = steps.find { |row| row["name"] == "Retain protected ASC review notes" }
    assert_includes artifact.fetch("if"), "always()"
    assert_includes artifact.fetch("if"), "inputs.include_review_notes"
    assert_equal "asc-review-notes.json", artifact.fetch("with").fetch("path")
    normal_artifact = steps.find { |row| row["name"] == "Retain ASC status snapshot" }
    assert_includes normal_artifact.fetch("if"), "!inputs.include_review_notes"
    refute_includes normal_artifact.fetch("with").fetch("path"), "asc-review-notes.json"
    refute_includes notes.fetch("run"), "submit"
  end

  private

  def with_cli(complete: true)
    Dir.mktmpdir("asc-review-notes-cli-") do |dir|
      marker = File.join(dir, "p8-read")
      output = File.join(dir, "result.json")
      summary = File.join(dir, "summary.md")
      fixture = File.join(dir, "fixture.json")
      preload = File.join(dir, "preload.rb")
      File.write(fixture, JSON.generate({
        "checked_at" => "2026-11-21T09:00:00Z", "complete" => complete,
        "app" => { "id" => "6822704143", "bundle_id" => "com.tripdelta.lite.app" },
        "version" => { "id" => "f991521a-405e-4422-be57-6f1dec949af2", "version_string" => "1.0.10" },
        "review_notes" => { "observation" => complete ? "present" : "unavailable", "notes" => CANARY, "sha256" => "b" * 64, "length" => 26, "byte_length" => 26 },
        "errors" => complete ? [] : [{ "secret" => CANARY }]
      }))
      File.write(preload, <<~STUB)
        require #{File.expand_path("lib/asc_review_status.rb", __dir__).inspect}
        require #{File.expand_path("lib/asc_review_notes.rb", __dir__).inspect}
        require "json"
        class << ENV
          alias_method :original_notes_fetch, :fetch
          def fetch(key, *args, &block)
            File.write(self["NOTES_MARKER"], "read") if key == "ASC_API_KEY_P8"
            original_notes_fetch(key, *args, &block)
          end
        end
        MajiaCI::ASCReviewStatus.define_singleton_method(:normalize_private_key) { |_secret| :fake_key }
        MajiaCI::ASCReadClient.define_singleton_method(:new) { |**_args| Object.new }
        MajiaCI::ASCReviewNotes.define_singleton_method(:read) { |**_args| JSON.parse(File.read(ENV.fetch("NOTES_FIXTURE"))) }
      STUB
      env = { "ASC_KEY_ID" => "ABC123DEFG", "ASC_ISSUER_ID" => "11111111-2222-4333-8444-555555555555",
              "ASC_API_KEY_P8" => CANARY, "NOTES_MARKER" => marker, "NOTES_FIXTURE" => fixture }
      args = [RbConfig.ruby, "-r", preload, CLI, "--bundle-id", "com.tripdelta.lite.app", "--output", output, "--github-summary", summary]
      yield args, env, output, summary, marker
    end
  end
end
