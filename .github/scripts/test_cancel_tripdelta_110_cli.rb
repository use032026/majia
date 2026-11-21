# frozen_string_literal: true

require "minitest/autorun"
require "tmpdir"
require "open3"
require "json"
require "rbconfig"
require "yaml"

class CancelTripDelta110CLITest < Minitest::Test
  CLI = File.expand_path("cancel-tripdelta-110-review.rb", __dir__)
  ROOT = File.expand_path("../..", __dir__)
  BUILD_ID = "12345678-1234-4123-8123-123456789abc"
  PRIVATE = "CANCEL110_PRIVATE_CANARY"

  def test_default_is_read_only_and_actual_build_number_is_forwarded_not_assumed_two
    with_cli do |args, env, output, summary, capture, _marker|
      File.write(output, "stale"); File.chmod(0o644, output)
      stdout, stderr, result = Open3.capture3(env, *args, unsetenv_others: true)
      assert result.success?, stderr
      sent = JSON.parse(File.read(capture))
      assert_equal false, sent["execute"]
      assert_equal BUILD_ID, sent["replacement_build_id"]
      assert_equal "3", sent["replacement_build_number"]
      assert_equal 0o600, File.stat(output).mode & 0o777
      assert_equal false, JSON.parse(File.read(output))["cancel_requested"]
      assert_includes File.read(summary), "Read-only preflight"
      refute_includes stdout + stderr + File.read(summary), PRIVATE
    end
  end

  def test_explicit_execute_only_forwards_true_to_fixed_library_after_validation
    with_cli do |args, env, output, _summary, capture, _marker|
      _stdout, stderr, result = Open3.capture3(env, *args, "--execute-cancel", "true", unsetenv_others: true)
      assert result.success?, stderr
      assert_equal true, JSON.parse(File.read(capture))["execute"]
      assert_equal true, JSON.parse(File.read(output))["completed"]
    end
  end

  def test_invalid_replacement_and_wrong_protected_bundle_never_read_p8_or_cancel
    changes = [ ["--replacement-build-id", "a130321b-d00b-4cda-95ca-d66d00e2c7e8"],
                ["--replacement-build-id", "not-a-uuid"], ["--replacement-build-number", "1"],
                ["--replacement-build-number", "2;echo bad"] ]
    changes.each do |extra|
      with_cli do |args, env, output, _summary, capture, marker|
        _stdout, _stderr, result = Open3.capture3(env, *args, *extra, unsetenv_others: true)
        refute result.success?
        refute File.exist?(marker)
        refute File.exist?(capture)
        assert_equal false, JSON.parse(File.read(output))["cancellation_complete"]
      end
    end
    with_cli do |args, env, _output, _summary, capture, marker|
      env["IOS_BUNDLE_ID"] = "wrong.bundle"
      refute Open3.capture3(env, *args, unsetenv_others: true).last.success?
      refute File.exist?(marker); refute File.exist?(capture)
    end
  end

  def test_failure_retains_safe_evidence_without_printing_remote_error
    with_cli(fail: true) do |args, env, output, summary, _capture, _marker|
      stdout, stderr, result = Open3.capture3(env, *args, "--execute-cancel", "true", unsetenv_others: true)
      refute result.success?
      failure = JSON.parse(File.read(output))
      assert_equal false, failure["cancellation_complete"]
      assert_equal false, failure.dig("evidence", "cancel_requested")
      assert_equal "cancellation_not_verified", failure["error"]
      refute_includes stdout + stderr + File.read(summary) + File.read(output), PRIVATE
    end
  end

  def test_workflow_keeps_same_environment_main_gate_lock_and_default_false
    workflow = YAML.load_file(File.join(ROOT, ".github/workflows/tripdelta-cancel-110-review.yml"))
    triggers = workflow.fetch("on") { workflow.fetch(true) }
    assert_equal ["workflow_dispatch"], triggers.keys
    inputs = triggers.fetch("workflow_dispatch").fetch("inputs")
    assert_equal %w[execute_cancel replacement_build_id replacement_build_number], inputs.keys.sort
    assert_equal false, inputs.fetch("execute_cancel").fetch("default")
    refute inputs.fetch("replacement_build_number").key?("default")
    assert_equal({ "contents" => "read" }, workflow.fetch("permissions"))
    assert_equal "majia-asc-tripdelta-production-${{ github.repository }}", workflow.dig("concurrency", "group")
    assert_equal false, workflow.dig("concurrency", "cancel-in-progress")
    job = workflow.fetch("jobs").fetch("cancel_review")
    assert_equal "tripdelta-production", job.fetch("environment")
    assert_includes job.fetch("if"), "refs/heads/main"
    assert_includes job.fetch("if"), "use032026/majia"
    action = job.fetch("steps").find { |step| step["run"] }
    assert_includes action.fetch("run"), '"$REPLACEMENT_BUILD_ID"'
    assert_includes action.fetch("run"), '"$REPLACEMENT_BUILD_NUMBER"'
    assert_includes action.fetch("run"), '"$EXECUTE_CANCEL"'
    refute_includes action.fetch("run"), "submit-asc"
    refute_includes action.fetch("run"), "prepare-existing"
    assert_equal "${{ always() }}", job.fetch("steps").last.fetch("if")
  end

  private

  def with_cli(fail: false)
    Dir.mktmpdir("cancel110-cli-") do |dir|
      output = File.join(dir, "receipt.json"); summary = File.join(dir, "summary.md")
      capture = File.join(dir, "call.json"); marker = File.join(dir, "p8-read")
      preload = File.join(dir, "preload.rb")
      File.write(preload, <<~STUB)
        require #{File.expand_path("lib/asc_tripdelta_110_cancellation.rb", __dir__).inspect}
        require "json"
        class << ENV
          alias_method :original_cancel110_fetch, :fetch
          def fetch(key, *args, &block)
            File.write(self["TEST_MARKER"], "read") if key == "ASC_API_KEY_P8"
            original_cancel110_fetch(key, *args, &block)
          end
        end
        MajiaCI::ASCReviewStatus.define_singleton_method(:normalize_private_key) { |_value| :fake_key }
        MajiaCI::ASCClient.define_singleton_method(:new) { |**_args| Object.new }
        MajiaCI::ASCTripDelta110Cancellation.define_singleton_method(:cancel) do |client:, **args|
          File.write(ENV.fetch("TEST_CAPTURE"), JSON.generate(args))
          if ENV["TEST_FAIL"] == "true"
            raise MajiaCI::ASCCancellationError.new(#{PRIVATE.inspect}, evidence: { "cancel_requested" => false, "completed" => false })
          end
          { "completed" => args[:execute], "cancel_requested" => args[:execute], "dry_run" => !args[:execute], "ready_to_cancel" => true }
        end
      STUB
      env = { "ASC_KEY_ID" => "ABC123DEFG", "ASC_ISSUER_ID" => "11111111-2222-4333-8444-555555555555",
              "ASC_API_KEY_P8" => PRIVATE, "IOS_BUNDLE_ID" => "com.tripdelta.lite.app",
              "TEST_CAPTURE" => capture, "TEST_MARKER" => marker, "TEST_FAIL" => fail.to_s }
      args = [RbConfig.ruby, "-r", preload, CLI, "--replacement-build-id", BUILD_ID, "--replacement-build-number", "3",
              "--output", output, "--github-output", File.join(dir, "github-output"), "--github-summary", summary]
      yield args, env, output, summary, capture, marker
    end
  end
end
