# frozen_string_literal: true

require "minitest/autorun"
require "tmpdir"
require "open3"
require "json"
require "rbconfig"
require "yaml"

class SubmitJufu103CLITest < Minitest::Test
  CLI = File.expand_path("submit-jufu-103-isolated-review.rb", __dir__)
  ROOT = File.expand_path("../..", __dir__)
  PRIVATE = "JUFU_PRIVATE_CANARY"

  def test_default_is_read_only_and_private_receipt_is_restricted
    with_cli do |args, env, out, summary, capture, _marker|
      File.write(out, "old"); File.chmod(0o644, out)
      stdout, stderr, status = Open3.capture3(env, *args, unsetenv_others: true)
      assert status.success?, stderr
      assert_equal false, JSON.parse(File.read(capture)).fetch("execute")
      assert_equal false, JSON.parse(File.read(out)).fetch("review_submitted")
      assert_equal 0o600, File.stat(out).mode & 0o777
      assert_includes File.read(summary), "Dry run: true"
      refute_includes stdout + stderr + File.read(summary), PRIVATE
    end
  end

  def test_explicit_execution_is_forwarded_and_receipt_is_verified
    with_cli do |args, env, out, summary, capture, _marker|
      _stdout, stderr, status = Open3.capture3(env, *args, "--execute-submit", "true", unsetenv_others: true)
      assert status.success?, stderr
      assert_equal true, JSON.parse(File.read(capture))["execute"]
      assert_equal true, JSON.parse(File.read(out))["review_submitted"]
      assert_includes File.read(summary), "Formal review verified: true"
    end
  end

  def test_invalid_flags_wrong_bundle_and_unknown_arguments_fail_before_credentials
    [ ["--execute-submit", "yes"], ["--marketing-version", "1.0.4"], ["unexpected"] ].each do |extra|
      with_cli do |args, env, _out, _summary, capture, marker|
        refute Open3.capture3(env, *args, *extra, unsetenv_others: true).last.success?
        refute File.exist?(marker)
        refute File.exist?(capture)
      end
    end
    with_cli do |args, env, _out, _summary, capture, marker|
      env["IOS_BUNDLE_ID"] = "com.jovfx.lite"
      refute Open3.capture3(env, *args, unsetenv_others: true).last.success?
      refute File.exist?(marker)
      refute File.exist?(capture)
    end
  end

  def test_sunday_forbids_formal_submission_but_keeps_read_only_preflight
    with_cli do |args, env, _out, _summary, capture, marker|
      env["TEST_SUNDAY"] = "true"
      refute Open3.capture3(env, *args, "--execute-submit", "true", unsetenv_others: true).last.success?
      refute File.exist?(marker)
      refute File.exist?(capture)
      assert Open3.capture3(env, *args, unsetenv_others: true).last.success?
      assert_equal false, JSON.parse(File.read(capture))["execute"]
    end
  end

  def test_failure_retains_phase_evidence_without_remote_message_or_credentials
    with_cli do |args, env, out, summary, _capture, _marker|
      env["TEST_FAIL"] = "true"
      stdout, stderr, status = Open3.capture3(env, *args, "--execute-submit", "true", unsetenv_others: true)
      refute status.success?
      failure = JSON.parse(File.read(out))
      assert_equal false, failure["review_submitted"]
      assert_equal "create_submission", failure.dig("evidence", "phase")
      assert_equal "isolated_submission_not_verified", failure["error"]
      refute_includes stdout + stderr + File.read(summary) + File.read(out), PRIVATE
    end
  end

  def test_unverified_execute_receipt_fails_closed
    with_cli do |args, env, out, _summary, _capture, _marker|
      env["TEST_UNVERIFIED"] = "true"
      refute Open3.capture3(env, *args, "--execute-submit", "true", unsetenv_others: true).last.success?
      assert_equal false, JSON.parse(File.read(out))["review_submitted"]
    end
  end

  def test_workflow_preserves_fixed_photo_environment_lock_and_default_read_only
    y = YAML.load_file(File.join(ROOT, ".github/workflows/jufu-submit-isolated-103-review.yml"))
    on = y.fetch("on") { y.fetch(true) }
    assert_equal ["workflow_dispatch"], on.keys
    inputs = on.fetch("workflow_dispatch").fetch("inputs")
    assert_equal ["execute_submit"], inputs.keys
    assert_equal false, inputs.fetch("execute_submit").fetch("default")
    assert_equal({ "contents" => "read" }, y.fetch("permissions"))
    assert_equal "majia-asc-photo-production-${{ github.repository }}", y.dig("concurrency", "group")
    assert_equal false, y.dig("concurrency", "cancel-in-progress")
    job = y.fetch("jobs").fetch("isolated_review")
    assert_equal "photo-production", job.fetch("environment")
    assert_includes job.fetch("if"), "refs/heads/main"
    assert_includes job.fetch("if"), "use032026/majia"
    step = job.fetch("steps").find { |candidate| candidate["run"] }
    assert_includes step.fetch("run"), '"$EXECUTE_SUBMIT"'
    refute_includes step.fetch("run"), "submit-asc-review.rb"
    refute_includes step.fetch("run"), "prepare-existing"
    assert_equal "${{ always() }}", job.fetch("steps").last.fetch("if")
  end

  private

  def with_cli
    Dir.mktmpdir("jufu103-cli-") do |dir|
      out = File.join(dir, "receipt.json"); summary = File.join(dir, "summary.md")
      capture = File.join(dir, "call.json"); marker = File.join(dir, "p8-read")
      preload = File.join(dir, "preload.rb")
      File.write(preload, <<~STUB)
        require #{File.expand_path("lib/asc_jufu_isolated_submission.rb", __dir__).inspect}
        require "json"
        class << ENV
          alias_method :original_jufu_fetch, :fetch
          def fetch(key, *args, &block)
            File.write(self["TEST_MARKER"], "read") if key == "ASC_API_KEY_P8"
            original_jufu_fetch(key, *args, &block)
          end
        end
        class << Time
          def now
            self.utc(2026, 11, ENV["TEST_SUNDAY"] == "true" ? 22 : 24, 4)
          end
        end
        MajiaCI::ASCReviewStatus.define_singleton_method(:normalize_private_key) { |_value| :fake }
        MajiaCI::ASCClient.define_singleton_method(:new) { |**_args| Object.new }
        MajiaCI::ASCJufuIsolatedSubmission.define_singleton_method(:run) do |client:, **args|
          File.write(ENV.fetch("TEST_CAPTURE"), JSON.generate(args))
          if ENV["TEST_FAIL"] == "true"
            raise MajiaCI::ASCJufuIsolatedSubmissionError.new(#{PRIVATE.inspect}, evidence: { "phase" => "create_submission", "error" => "request_failed" })
          end
          { "ready_to_submit" => true, "review_submitted" => args[:execute] && ENV["TEST_UNVERIFIED"] != "true", "no_op" => false }
        end
      STUB
      env = { "ASC_KEY_ID" => "ABC123DEFG", "ASC_ISSUER_ID" => "11111111-2222-4333-8444-555555555555",
              "ASC_API_KEY_P8" => PRIVATE, "IOS_BUNDLE_ID" => "com.lunelle.lite",
              "TEST_CAPTURE" => capture, "TEST_MARKER" => marker }
      args = [RbConfig.ruby, "-r", preload, CLI, "--output", out,
              "--github-output", File.join(dir, "github-output"), "--github-summary", summary]
      yield args, env, out, summary, capture, marker
    end
  end
end
