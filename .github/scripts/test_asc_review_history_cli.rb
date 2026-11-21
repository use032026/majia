# frozen_string_literal: true

require "minitest/autorun"
require "open3"
require "tmpdir"
require "json"
require "yaml"
require "rbconfig"

class ASCReviewHistoryCLITest < Minitest::Test
  CLI = File.expand_path("query-asc-review-status.rb", __dir__)
  ROOT = File.expand_path("../..", __dir__)
  CANARY = "PRIVATE_CANARY_NOT_FOR_OUTPUT"

  def test_history_cli_writes_private_artifact_and_safe_summary
    with_cli do |args, env, output, summary, marker|
      stdout, stderr, status = Open3.capture3(env, *args, "--review-history", unsetenv_others: true)
      assert status.success?, stderr
      assert_includes stdout, "ASC review history queried"
      assert File.exist?(marker)
      assert_equal 0o600, File.stat(output).mode & 0o777
      assert_equal 9, JSON.parse(File.read(output))["confirmed_distinct_submitted_lower_bound"]
      assert_includes File.read(summary), "review history lower bound"
      refute_includes stdout + stderr + File.read(summary), CANARY
    end
  end

  def test_partial_history_keeps_evidence_and_nonzero_exit
    with_cli(complete: false) do |args, env, output, summary, _marker|
      _stdout, stderr, status = Open3.capture3(env, *args, "--review-history", unsetenv_others: true)
      refute status.success?, stderr
      assert_equal false, JSON.parse(File.read(output))["api_scan_complete"]
      assert File.exist?(summary)
      refute_includes File.read(summary), CANARY
    end
  end

  def test_conflicting_modes_and_version_fail_before_secret_access
    [ ["--review-diagnostics"], ["--build-inventory"], ["--marketing-version", "1.0.7"] ].each do |extra|
      with_cli do |args, env, output, summary, marker|
        stdout, stderr, status = Open3.capture3(env, *args, "--review-history", *extra, unsetenv_others: true)
        refute status.success?
        refute File.exist?(marker), "secret was fetched before mode validation"
        refute File.exist?(output)
        refute File.exist?(summary)
        refute_includes stdout + stderr, CANARY
      end
    end
  end

  def test_workflow_keeps_existing_protection_and_wires_exclusive_history_mode
    workflow = YAML.load_file(File.join(ROOT, ".github/workflows/asc-review-status.yml"))
    triggers = workflow.fetch("on") { workflow.fetch(true) }
    assert_equal ["workflow_dispatch"], triggers.keys
    input = triggers.fetch("workflow_dispatch").fetch("inputs").fetch("include_review_history")
    assert_equal false, input.fetch("default")
    assert_equal "boolean", input.fetch("type")
    assert_equal({ "contents" => "read" }, workflow.fetch("permissions"))
    job = workflow.fetch("jobs").fetch("query")
    assert_equal "${{ inputs.app_environment }}", job.fetch("environment")
    steps = job.fetch("steps")
    history = steps.find { |row| row["name"] == "Query read-only ASC review history" }
    assert_equal "${{ inputs.include_review_history }}", history.fetch("if")
    assert_includes history.fetch("run"), "--review-history"
    assert_includes history.fetch("run"), "Review history cannot be combined with other query modes"
    %w[MARKETING_VERSION INVENTORY_VERSION INCLUDE_STORE_METADATA INCLUDE_REVIEW_DIAGNOSTICS].each do |key|
      assert history.fetch("env").key?(key)
      assert_includes history.fetch("run"), key
    end
    steps.select { |row| row["name"].start_with?("Query read-only ASC") && row != history }.each do |row|
      assert_includes row.fetch("if"), "!inputs.include_review_history"
    end
    retain = steps.find { |row| row["name"] == "Retain ASC status snapshot" }
    assert_includes retain.fetch("if"), "inputs.include_review_history"
    assert_includes retain.fetch("with").fetch("path"), "asc-review-history.json"
    refute_includes history.fetch("run"), "submit-asc-review"
    refute_includes history.fetch("run"), "prepare-existing-asc-release"
  end

  private

  def with_cli(complete: true)
    Dir.mktmpdir("asc-history-cli-") do |dir|
      fixture = File.join(dir, "fixture.json")
      output = File.join(dir, "snapshot.json")
      summary = File.join(dir, "summary.md")
      marker = File.join(dir, "secret-access")
      preload = File.join(dir, "preload.rb")
      File.write(fixture, JSON.generate({
        "checked_at" => "2026-11-21T01:00:00Z",
        "app" => { "id" => "6825229832", "bundle_id" => "com.fylto.lite" },
        "confirmed_distinct_submitted_lower_bound" => 9, "distinct_versions" => [],
        "api_scan_complete" => complete, "history_complete" => false,
        "decision" => { "label" => "可使用", "stop_auto_submission" => true },
        "errors" => complete ? [] : [{ "message" => CANARY }], "unknowns" => [], "private_key" => CANARY
      }))
      File.write(preload, <<~RUBY)
        require #{File.expand_path("lib/asc_review_status.rb", __dir__).inspect}
        require #{File.expand_path("lib/asc_review_history.rb", __dir__).inspect}
        require "json"
        class << ENV
          alias_method :original_history_test_fetch, :fetch
          def fetch(key, *args, &block)
            File.write(self["TEST_MARKER"], "fetched") if key == "ASC_API_KEY_P8"
            original_history_test_fetch(key, *args, &block)
          end
        end
        MajiaCI::ASCReviewStatus.define_singleton_method(:normalize_private_key) { |_value| :test_key }
        MajiaCI::ASCReadClient.define_singleton_method(:new) { |**_args| Object.new }
        MajiaCI::ASCReviewHistory.define_singleton_method(:read) { |**_args| JSON.parse(File.read(ENV.fetch("TEST_FIXTURE"))) }
      RUBY
      env = {
        "ASC_KEY_ID" => "ABC123DEFG", "ASC_ISSUER_ID" => "11111111-2222-4333-8444-555555555555",
        "ASC_API_KEY_P8" => CANARY, "TEST_MARKER" => marker, "TEST_FIXTURE" => fixture
      }
      args = [RbConfig.ruby, "-r", preload, CLI, "--bundle-id", "com.fylto.lite", "--output", output, "--github-summary", summary]
      yield args, env, output, summary, marker
    end
  end
end
