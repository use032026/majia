# frozen_string_literal: true

require "minitest/autorun"
require "open3"
require "tmpdir"
require "yaml"
require_relative "lib/deynu_review_notes"

class DeynuReviewNotesTest < Minitest::Test
  Tool = MajiaCI::DeynuReviewNotes
  VID = "11111111-1111-1111-1111-111111111111"
  DID = "22222222-2222-2222-2222-222222222222"
  OTHER = "33333333-3333-3333-3333-333333333333"
  PRIVATE = "PRIVATE-NOTES-CONTACT-ACCOUNT-ERROR-MARKER"

  class FakeClient
    attr_reader :calls
    attr_accessor :app, :versions, :build, :detail, :after, :patch_result, :on_get
    def initialize
      @calls = []
      @app = { "data" => { "type" => "apps", "id" => Tool::APP_ID,
        "attributes" => { "bundleId" => Tool::BUNDLE_ID } } }
      @versions = { "data" => [{ "type" => "appStoreVersions", "id" => VID,
        "attributes" => { "platform" => "IOS", "versionString" => Tool::VERSION,
          "appVersionState" => "PREPARE_FOR_SUBMISSION", "releaseType" => "AFTER_APPROVAL" } }] }
      @build = { "data" => { "type" => "builds", "id" => Tool::BUILD_ID,
        "attributes" => { "version" => Tool::BUILD_NUMBER, "processingState" => "VALID", "expired" => false } } }
      @detail = { "data" => { "type" => "appStoreReviewDetails", "id" => DID,
        "attributes" => { "notes" => PRIVATE, "contactEmail" => PRIVATE, "demoAccountPassword" => PRIVATE } } }
      @after = Marshal.load(Marshal.dump(@detail))
      @after["data"]["attributes"]["notes"] = "Approved local test notes"
      @patch_result = { "data" => { "type" => "appStoreReviewDetails", "id" => DID } }
    end
    def get(path, query = nil)
      @calls << [:get, path, query]
      @on_get.call(self, path) if @on_get
      result = case path
      when "/v1/apps/#{Tool::APP_ID}" then app
      when "/v1/apps/#{Tool::APP_ID}/appStoreVersions" then versions
      when "/v1/appStoreVersions/#{VID}/build", "/v1/appStoreVersions/#{OTHER}/build" then build
      when "/v1/appStoreVersions/#{VID}/appStoreReviewDetail", "/v1/appStoreVersions/#{OTHER}/appStoreReviewDetail" then detail
      when "/v1/appStoreReviewDetails/#{DID}" then after
      else raise "#{PRIVATE} unknown get"
      end
      raise result if result.is_a?(Exception)
      Marshal.load(Marshal.dump(result))
    end
    def patch(path, payload)
      @calls << [:patch, path, payload]
      raise patch_result if patch_result.is_a?(Exception)
      patch_result
    end
  end

  def setup
    @client = FakeClient.new
  end

  def sync(**options)
    Tool.sync(client: @client, marketing_version: Tool::VERSION, build_number: Tool::BUILD_NUMBER,
      expected_build_id: Tool::BUILD_ID, **options)
  end
  def apply(**options)
    defaults = { apply: true, desired_notes: "Approved local test notes", expected_current_hash: Tool.notes_hash(PRIVATE) }
    sync(**defaults.merge(options))
  end
  def patches
    @client.calls.select { |verb, _path, _body| verb == :patch }
  end
  def safe(result)
    refute_includes JSON.generate(result), PRIVATE
    refute_includes JSON.generate(result), "contactEmail"
    refute_includes JSON.generate(result), "demoAccountPassword"
    result
  end

  # Local transport replacement avoids requiring a separate minitest-mock gem.
  # The real ASCClient request construction/parser still runs, without sockets.
  def stub_method(object, method, replacement)
    original = object.method(method)
    object.singleton_class.send(:define_method, method, &replacement)
    yield
  ensure
    object.singleton_class.send(:define_method, method, original) if original
  end

  def test_default_zero_writes_and_safe_hash_only_output
    result = safe(sync)
    assert_equal "read_only", result["status"]
    assert_equal false, result["write_attempted"]
    assert_equal false, result["may_have_written"]
    assert_equal Tool.notes_hash(PRIVATE), result["current_notes_hash"]
    assert_nil result["matches_desired"]
    assert_empty patches
    assert_equal 4, @client.calls.length
    assert_equal "notes", @client.calls.last[2]["fields[appStoreReviewDetails]"]
    assert_equal Tool::SOURCE_COMMIT, result.dig("local_signed_evidence", "source_commit")
    refute result.key?("source_sha")
  end

  def test_apply_one_patch_with_only_notes_and_sparse_same_detail_readback
    result = safe(apply)
    assert_equal "written_and_verified", result["status"]
    assert_equal true, result["verified"]
    assert_equal true, result["write_attempted"]
    assert_equal true, result["may_have_written"]
    assert_equal 1, patches.length
    assert_equal({ "data" => { "type" => "appStoreReviewDetails", "id" => DID,
      "attributes" => { "notes" => "Approved local test notes" } } }, patches.first[2])
    assert_equal [:get, "/v1/appStoreReviewDetails/#{DID}", Tool::NOTES_FIELDS], @client.calls.last
    assert_equal 2, @client.calls.count { |verb, path, _| verb == :get && path == "/v1/apps/#{Tool::APP_ID}" }
    assert @client.calls.all? { |verb, _path, _| [:get, :patch].include?(verb) }
  end

  def test_null_empty_and_string_hashes_are_distinct_and_missing_is_not_null
    hashes = [nil, "", "null", " ", "é", "e\u0301"].map { |notes| Tool.notes_hash(notes) }
    assert_equal hashes.length, hashes.uniq.length
    [nil, "", "existing"].zip(%w[null empty_string string]).each do |notes, state|
      @client = FakeClient.new
      @client.detail["data"]["attributes"]["notes"] = notes
      result = sync
      assert_equal state, result["current_notes_state"]
      assert_equal Tool.notes_hash(notes), result["current_notes_hash"]
      assert_empty patches
    end
    @client.detail["data"]["attributes"].delete("notes")
    assert_equal "missing_notes_field", sync["error_code"]
    assert_empty patches
  end

  def test_unicode_is_exact_no_normalization_and_noop_writes_nothing
    notes = "已批准\nLocal café 😀"
    @client.detail["data"]["attributes"]["notes"] = notes
    result = sync(apply: true, desired_notes: notes, expected_current_hash: Tool.notes_hash(notes))
    assert_equal true, result["no_op"]
    assert_equal true, result["verified"]
    assert_equal "unchanged", result["status"]
    assert_equal 4, @client.calls.length
    assert_empty patches
    @client = FakeClient.new
    @client.after["data"]["attributes"]["notes"] = notes
    assert_equal true, apply(desired_notes: notes)["verified"]
  end

  def test_every_identity_state_build_and_detail_guard_prevents_writes
    mutations = [
      ->(c) { c.app["data"]["id"] = "other" },
      ->(c) { c.app["data"]["type"] = "wrong" },
      ->(c) { c.app["data"]["attributes"]["bundleId"] = "other.bundle" },
      ->(c) { c.versions["data"] = [] },
      ->(c) { c.versions["data"] *= 2 },
      ->(c) { c.versions["links"] = { "next" => "https://untrusted.invalid/next" } },
      ->(c) { c.versions["data"][0]["id"] = PRIVATE },
      ->(c) { c.versions["data"][0]["type"] = "wrong" },
      ->(c) { c.versions["data"][0]["attributes"]["platform"] = "MAC_OS" },
      ->(c) { c.versions["data"][0]["attributes"]["versionString"] = "1.0.12" },
      ->(c) { c.versions["data"][0]["attributes"]["appVersionState"] = "WAITING_FOR_REVIEW" },
      ->(c) { c.versions["data"][0]["attributes"]["releaseType"] = "MANUAL" },
      ->(c) { c.build["data"] = nil },
      ->(c) { c.build["data"]["id"] = OTHER },
      ->(c) { c.build["data"]["type"] = "wrong" },
      ->(c) { c.build["data"]["attributes"]["version"] = "2" },
      ->(c) { c.build["data"]["attributes"]["processingState"] = "PROCESSING" },
      ->(c) { c.build["data"]["attributes"]["expired"] = true },
      ->(c) { c.build["data"]["attributes"].delete("expired") },
      ->(c) { c.detail["data"] = nil },
      ->(c) { c.detail["data"]["type"] = "wrong" },
      ->(c) { c.detail["data"]["id"] = PRIVATE },
      ->(c) { c.detail["data"].delete("attributes") },
      ->(c) { c.detail["data"]["attributes"].delete("notes") },
      ->(c) { c.detail["data"]["attributes"]["notes"] = 7 },
      ->(c) { c.detail["data"]["attributes"]["notes"] = "bad\0notes" }
    ]
    mutations.each_with_index do |mutation, index|
      @client = FakeClient.new; mutation.call(@client)
      result = safe(apply)
      assert result["error_code"], "guard #{index}"
      assert_equal false, result["write_attempted"]
      assert_empty patches
    end
  end

  def test_exact_hardpin_and_real_boolean_required_before_reads
    ["true", "false", nil, 1].each do |value|
      @client = FakeClient.new
      assert_equal "invalid_inputs", sync(apply: value)["error_code"]
      assert_empty @client.calls
    end
    [{ marketing_version: "1.0.12" }, { build_number: "2" }, { expected_build_id: OTHER }].each do |change|
      result = Tool.sync(client: @client, marketing_version: Tool::VERSION, build_number: "1",
        expected_build_id: Tool::BUILD_ID, **change)
      assert_equal "invalid_inputs", result["error_code"]
      assert_empty @client.calls
    end
  end

  def test_apply_invalid_notes_or_hash_never_reads_or_writes
    [nil, "", " \n\t", "bad\0notes", "bad\u0007notes", 1, false, "x" * 4001,
     "\xC3\x28".dup.force_encoding(Encoding::UTF_8)].each do |notes|
      @client = FakeClient.new
      assert apply(desired_notes: notes)["error_code"]
      assert_empty @client.calls
    end
    [nil, "", "abc", "A" * 64, 7].each do |hash|
      @client = FakeClient.new
      assert_equal "expected_hash_required", apply(expected_current_hash: hash)["error_code"]
      assert_empty @client.calls
    end
  end

  def test_current_hash_required_match_and_noop_does_not_override_precondition
    assert_equal "current_hash_mismatch", apply(expected_current_hash: "0" * 64)["error_code"]
    assert_empty patches
    assert_equal "current_hash_mismatch", apply(desired_notes: PRIVATE, expected_current_hash: "0" * 64)["error_code"]
    assert_empty patches
  end

  def test_prewrite_notes_state_build_version_and_detail_drift_all_stop_the_patch
    changes = [
      ->(c) { c.detail["data"]["attributes"]["notes"] = "drift" },
      ->(c) { c.versions["data"][0]["attributes"]["appVersionState"] = "IN_REVIEW" },
      ->(c) { c.versions["data"][0]["id"] = OTHER },
      ->(c) { c.detail["data"]["id"] = OTHER },
      ->(c) { c.build["data"]["id"] = OTHER }
    ]
    changes.each do |change|
      @client = FakeClient.new
      count = 0
      @client.on_get = ->(client, path) do
        if path == "/v1/apps/#{Tool::APP_ID}"
          count += 1; change.call(client) if count == 2
        end
      end
      result = safe(apply)
      assert result["error_code"]
      assert_equal false, result["write_attempted"]
      assert_empty patches
    end
  end

  def test_patch_ambiguous_errors_and_json_failures_never_retry_or_rollback
    outcomes = [Timeout::Error.new(PRIVATE), JSON::ParserError.new(PRIVATE),
      MajiaCI::ASCStatusError.new("HTTP 500 #{PRIVATE}"), {}, { "data" => { "type" => "wrong", "id" => DID } }]
    outcomes.each do |outcome|
      @client = FakeClient.new; @client.patch_result = outcome
      result = safe(apply)
      assert result["error_code"]
      assert_equal true, result["write_attempted"]
      assert_equal true, result["may_have_written"]
      assert_equal false, result["verified"]
      assert_equal true, result["post_read_matches_desired"]
      assert_equal 1, patches.length
      assert_equal :get, @client.calls.last.first
    end
  end

  def test_wrong_post_readback_and_failed_readback_never_repeat_patch
    ["different notes", nil, 7, :missing, :wrong_id, :read_error].each do |outcome|
      @client = FakeClient.new
      case outcome
      when :missing then @client.after["data"]["attributes"].delete("notes")
      when :wrong_id then @client.after["data"]["id"] = OTHER
      when :read_error then @client.after = RuntimeError.new(PRIVATE)
      else @client.after["data"]["attributes"]["notes"] = outcome
      end
      result = safe(apply)
      assert result["error_code"]
      assert_equal false, result["verified"]
      assert_equal true, result["may_have_written"]
      assert_equal 1, patches.length
    end
  end

  def test_upstream_sensitive_exceptions_never_enter_summary
    @client.app = RuntimeError.new(PRIVATE)
    result = safe(apply)
    assert_equal "unexpected_failure", result["error_code"]
    assert_empty patches
    refute result.key?("error")
  end

  def test_real_transport_stub_patch_max_retries_zero_and_get_at_most_three
    http = Object.new
    http.singleton_class.attr_accessor :max_retries, :requests, :outcome
    http.requests = []
    http.define_singleton_method(:request) do |request|
      requests << request
      raise outcome if outcome.is_a?(Exception)
      outcome
    end
    good = Net::HTTPOK.new("1.1", "200", "OK")
    good.instance_variable_set(:@read, true)
    good.body = JSON.generate("data" => { "type" => "appStoreReviewDetails", "id" => DID })
    http.outcome = good
    http_factory = ->(*_args, **_options, &block) { block.call(http) }
    client = MajiaCI::DeynuReviewNotesClient.new(key: nil, key_id: "unused", issuer_id: "unused")
    stub_method(MajiaCI::ASCReviewStatus, :jwt, ->(**_options) { "FAKE-NO-CREDENTIALS" }) do
      stub_method(Net::HTTP, :start, http_factory) do
        client.patch("/v1/appStoreReviewDetails/#{DID}", { "data" => { "type" => "appStoreReviewDetails", "id" => DID, "attributes" => { "notes" => "fake" } } })
        assert_equal 0, http.max_retries
        assert_equal ["PATCH"], http.requests.map(&:method)
        assert_equal({ "notes" => "fake" }, JSON.parse(http.requests.first.body).dig("data", "attributes"))
        http.requests.clear; http.outcome = Timeout::Error.new(PRIVATE)
        error = assert_raises(MajiaCI::DeynuReviewNotesError) { client.patch("/v1/appStoreReviewDetails/#{DID}", {}) }
        assert_equal "patch_unconfirmed", error.code
        refute_includes error.message, PRIVATE
        assert_equal 1, http.requests.length
        http.requests.clear
        error = assert_raises(MajiaCI::DeynuReviewNotesError) { client.get("/v1/apps/#{Tool::APP_ID}") }
        assert_equal "read_unavailable", error.code
        assert_equal 3, http.requests.length
        assert_equal 0, http.max_retries
        assert http.requests.all? { |request| request.method == "GET" }
      end
    end
  end

  def test_real_transport_rejects_wrong_http_status_and_invalid_json_without_patch_retry
    responses = [Net::HTTPCreated.new("1.1", "201", "Created"), Net::HTTPInternalServerError.new("1.1", "500", "Error"),
      Net::HTTPOK.new("1.1", "200", "OK")]
    responses[0].body = "{}"
    responses[1].body = JSON.generate("errors" => [{ "detail" => PRIVATE }])
    responses[2].body = PRIVATE
    client = MajiaCI::DeynuReviewNotesClient.new(key: nil, key_id: "unused", issuer_id: "unused")
    responses.each do |response|
      response.instance_variable_set(:@read, true)
      count = 0
      http = Object.new
      http.singleton_class.attr_accessor :max_retries
      http.define_singleton_method(:request) { |_request| count += 1; response }
      stub_method(MajiaCI::ASCReviewStatus, :jwt, ->(**_options) { "FAKE" }) do
        stub_method(Net::HTTP, :start, ->(*_args, **_options, &block) { block.call(http) }) do
          error = assert_raises(MajiaCI::DeynuReviewNotesError) { client.patch("/v1/appStoreReviewDetails/#{DID}", {}) }
          assert_equal "patch_unconfirmed", error.code
          assert_equal 1, count
          assert_equal 0, http.max_retries
          refute_includes error.message, PRIVATE
        end
      end
    end
  end

  def test_cli_failure_json_stdout_stderr_never_echo_inputs_or_exception
    Dir.mktmpdir do |directory|
      preloader = File.join(directory, "fake.rb")
      File.write(preloader, <<~CODE)
        require #{File.expand_path('lib/deynu_review_notes', __dir__).inspect}
        class MajiaCI::DeynuReviewNotesClient
          def get(*); raise #{PRIVATE.inspect}; end
        end
      CODE
      output = File.join(directory, "safe.json")
      key = OpenSSL::PKey::EC.generate("prime256v1")
      environment = {
        "RUBYOPT" => "-r#{preloader}", "DEYNU_REVIEW_VERSION" => Tool::VERSION,
        "DEYNU_REVIEW_BUILD" => "1", "DEYNU_REVIEW_EXPECTED_BUILD_ID" => Tool::BUILD_ID,
        "DEYNU_REVIEW_NOTES_TEXT" => PRIVATE, "DEYNU_REVIEW_APPLY" => "false",
        "ASC_KEY_ID" => "ABCDEFGHIJ", "ASC_ISSUER_ID" => "12345678-1234-1234-1234-123456789abc",
        "ASC_API_KEY_P8" => key.to_pem
      }
      stdout, stderr, status = Open3.capture3(environment, RbConfig.ruby,
        File.expand_path("sync-deynu-review-notes.rb", __dir__), "--output", output)
      refute status.success?
      assert_equal "unexpected_failure", JSON.parse(stdout)["error_code"]
      assert_equal "", stderr
      refute_includes stdout + stderr + File.read(output), PRIVATE
      assert_equal 0o600, File.stat(output).mode & 0o777
    end
  end

  def test_cli_rejects_invalid_bool_unsafe_file_and_empty_apply_before_network
    Dir.mktmpdir do |directory|
      notes = File.join(directory, "notes.txt"); File.write(notes, PRIVATE); File.chmod(0o644, notes)
      base = { "DEYNU_REVIEW_VERSION" => Tool::VERSION, "DEYNU_REVIEW_BUILD" => "1",
        "DEYNU_REVIEW_EXPECTED_BUILD_ID" => Tool::BUILD_ID, "ASC_API_KEY_P8" => PRIVATE,
        "DEYNU_REVIEW_NOTES_TEXT" => nil, "DEYNU_REVIEW_NOTES_FILE" => nil, "RUBYOPT" => nil }
      [ { "DEYNU_REVIEW_APPLY" => "TRUE" }, { "DEYNU_REVIEW_NOTES_FILE" => notes },
        { "DEYNU_REVIEW_APPLY" => "true", "DEYNU_REVIEW_NOTES_TEXT" => "" } ].each do |change|
        stdout, stderr, status = Open3.capture3(base.merge(change), RbConfig.ruby,
          File.expand_path("sync-deynu-review-notes.rb", __dir__))
        refute status.success?
        assert_equal "configuration_or_evidence_io_failed", JSON.parse(stdout)["error_code"]
        assert_equal "", stderr
        refute_includes stdout + stderr, PRIVATE
      end
    end
  end

  def test_patch_and_postread_interruptions_preserve_possible_write_without_retry
    [Interrupt.new(PRIVATE), SystemExit.new(3)].each do |interruption|
      [:patch, :postread].each do |stage|
        @client = FakeClient.new
        if stage == :patch then @client.patch_result = interruption
        else @client.after = interruption
        end
        result = safe(apply)
        assert_equal "failed", result["status"]
        assert_equal true, result["write_attempted"]
        assert_equal true, result["may_have_written"]
        assert_equal false, result["verified"]
        assert_equal 1, patches.length
        assert result["error_code"]
      end
    end
  end

  def test_cli_writer_invocation_interruption_is_unknown_not_zero_writes
    Dir.mktmpdir do |directory|
      preloader = File.join(directory, "interrupt.rb")
      File.write(preloader, <<~CODE)
        require #{File.expand_path('lib/deynu_review_notes', __dir__).inspect}
        module MajiaCI::DeynuReviewNotes
          def self.sync(**); raise Interrupt, #{PRIVATE.inspect}; end
        end
      CODE
      key = OpenSSL::PKey::EC.generate("prime256v1")
      env = { "RUBYOPT" => "-r#{preloader}", "DEYNU_REVIEW_VERSION" => Tool::VERSION,
        "DEYNU_REVIEW_BUILD" => "1", "DEYNU_REVIEW_EXPECTED_BUILD_ID" => Tool::BUILD_ID,
        "DEYNU_REVIEW_APPLY" => "false", "DEYNU_REVIEW_NOTES_TEXT" => nil, "DEYNU_REVIEW_NOTES_FILE" => nil,
        "ASC_KEY_ID" => "ABCDEFGHIJ", "ASC_ISSUER_ID" => "12345678-1234-1234-1234-123456789abc",
        "ASC_API_KEY_P8" => key.to_pem }
      stdout, stderr, status = Open3.capture3(env, RbConfig.ruby, File.expand_path("sync-deynu-review-notes.rb", __dir__))
      refute status.success?
      result = safe(JSON.parse(stdout))
      assert_nil result["write_attempted"]
      assert_equal true, result["may_have_written"]
      assert_equal true, result["write_outcome_unknown"]
      assert_equal false, result["verified"]
      assert_equal "", stderr
    end
  end

  def workflow_wrapper_source
    workflow = YAML.load_file(File.expand_path("../workflows/deynu-review-notes.yml", __dir__))
    run = workflow.dig("jobs", "review_notes", "steps").last.fetch("run")
    run.lines.drop(1).take_while { |line| line.strip != "RUBY" }.join
  end

  def run_workflow_wrapper(event_bytes:, expected_notes: "", interrupt: false, event_path: :file)
    Dir.mktmpdir do |directory|
      injection = File.join(directory, "injection-executed")
      yield_notes = expected_notes.respond_to?(:call) ? expected_notes.call(injection) : expected_notes
      bytes = event_bytes.respond_to?(:call) ? event_bytes.call(yield_notes) : event_bytes
      event_file = File.join(directory, "event.json")
      File.binwrite(event_file, bytes) unless event_path == :missing
      receipt = File.join(directory, "receipt")
      preloader = File.join(directory, "system_stub.rb")
      File.write(preloader, <<~CODE)
        require "json"
        require "digest"
        module Kernel
          def system(*args)
            path = ENV.fetch("DEYNU_REVIEW_NOTES_FILE")
            raise "unsafe mode" unless (File.stat(path).mode & 0o777) == 0o600
            raise "unsafe env" if ENV.key?("DEYNU_REVIEW_NOTES_TEXT")
            raise "wrong content" unless File.binread(path) == ENV.fetch("FAKE_EXPECTED_NOTES").b
            raise "wrong command" unless args == [RbConfig.ruby, ".github/scripts/sync-deynu-review-notes.rb"]
            File.write(ENV.fetch("FAKE_RECEIPT"), JSON.generate("validated" => true,
              "notes_sha256" => Digest::SHA256.file(path).hexdigest))
            raise Interrupt, #{PRIVATE.inspect} if ENV["FAKE_INTERRUPT"] == "true"
            # A safe real child supplies normal $? semantics without ASC/CLI.
            Process.wait(Process.spawn(RbConfig.ruby, "-e", "exit 0"))
            puts JSON.generate("status" => "read_only", "write_attempted" => false,
              "may_have_written" => false, "verified" => false)
            true
          end
        end
      CODE
      environment = { "RUNNER_TEMP" => directory, "GITHUB_EVENT_PATH" => event_path == :unset ? nil : event_file,
        "DEYNU_REVIEW_NOTES_TEXT" => PRIVATE, "RUBYOPT" => nil,
        "DEYNU_REVIEW_APPLY" => "false", "FAKE_EXPECTED_NOTES" => yield_notes,
        "FAKE_RECEIPT" => receipt, "FAKE_INTERRUPT" => interrupt.to_s }
      stdout, stderr, status = Open3.capture3(environment, RbConfig.ruby, "-r", preloader,
        stdin_data: workflow_wrapper_source)
      { stdout: stdout, stderr: stderr, status: status, receipt: File.file?(receipt) ? JSON.parse(File.read(receipt)) : nil,
        leftovers: Dir.glob(File.join(directory, "deynu-review-notes-*")),
        injection_executed: File.exist?(injection), expected_notes: yield_notes }
    end
  end

  def test_workflow_event_unicode_multiline_injection_text_is_only_private_file_data
    notes = ->(marker) { "中文 café 😀\n#{PRIVATE}\n$(touch #{marker}) `touch #{marker}`\n${HOME}" }
    outcome = run_workflow_wrapper(event_bytes: ->(value) { JSON.generate("inputs" => { "notes" => value }) }, expected_notes: notes)
    assert outcome[:status].success?
    assert_equal "", outcome[:stderr]
    result = safe(JSON.parse(outcome[:stdout]))
    assert_equal "read_only", result["status"]
    assert_equal false, result["write_attempted"]
    assert_equal true, outcome.dig(:receipt, "validated")
    assert_equal Digest::SHA256.hexdigest(outcome[:expected_notes]), outcome.dig(:receipt, "notes_sha256")
    refute outcome[:injection_executed]
    refute_includes outcome[:stdout], outcome[:expected_notes]
    assert_empty outcome[:leftovers]
  end

  def test_workflow_missing_optional_notes_is_empty_in_readonly_and_interrupt_retains_uncertainty
    normal = run_workflow_wrapper(event_bytes: JSON.generate("inputs" => {}))
    assert normal[:status].success?
    assert_equal true, normal.dig(:receipt, "validated")
    assert_equal Digest::SHA256.hexdigest(""), normal.dig(:receipt, "notes_sha256")
    assert_empty normal[:leftovers]
    interrupted = run_workflow_wrapper(event_bytes: JSON.generate("inputs" => { "notes" => PRIVATE }),
      expected_notes: PRIVATE, interrupt: true)
    refute interrupted[:status].success?
    result = safe(JSON.parse(interrupted[:stdout]))
    assert_nil result["write_attempted"]
    assert_equal true, result["may_have_written"]
    assert_equal true, result["write_outcome_unknown"]
    assert_equal "", interrupted[:stderr]
    assert_empty interrupted[:leftovers]
    assert_equal 1, interrupted[:stdout].lines.length
    assert_equal true, interrupted.dig(:receipt, "validated")
  end

  def test_workflow_bad_event_input_fails_before_child_with_only_safe_json
    bodies = [
      JSON.generate("inputs" => { "notes" => nil }),
      JSON.generate("inputs" => { "notes" => 7 }),
      JSON.generate("inputs" => { "notes" => false }),
      JSON.generate("inputs" => { "notes" => [] }),
      JSON.generate("inputs" => nil), JSON.generate("inputs" => []), JSON.generate([]), JSON.generate({}),
      "{#{PRIVATE}",
      "{\"inputs\":{\"notes\":\"#{PRIVATE}".b + "\xC3\x28".b,
      JSON.generate("inputs" => { "notes" => "x" * 4001 }),
      JSON.generate("inputs" => { "notes" => "😀" * 4001 }),
      JSON.generate("inputs" => { "notes" => "bad\0#{PRIVATE}" }),
      " " * 1_048_577
    ]
    bodies.each_with_index do |body, index|
      outcome = run_workflow_wrapper(event_bytes: body)
      refute outcome[:status].success?, "event case #{index}"
      result = safe(JSON.parse(outcome[:stdout]))
      assert_equal "configuration_or_evidence_io_failed", result["error_code"]
      assert_equal false, result["write_attempted"]
      assert_equal false, result["may_have_written"]
      assert_equal false, result["write_outcome_unknown"]
      assert_equal "", outcome[:stderr]
      assert_equal 1, outcome[:stdout].lines.length
      assert_nil outcome[:receipt]
      assert_empty outcome[:leftovers]
    end
    [:unset, :missing].each do |path|
      outcome = run_workflow_wrapper(event_bytes: "{}", event_path: path)
      refute outcome[:status].success?
      result = safe(JSON.parse(outcome[:stdout]))
      assert_equal false, result["write_attempted"]
      assert_equal false, result["may_have_written"]
      assert_equal "", outcome[:stderr]
      assert_nil outcome[:receipt]
      assert_empty outcome[:leftovers]
    end
  end

  def test_runner_pre_execution_header_has_no_notes_input_value_or_expression
    workflow = YAML.load_file(File.expand_path("../workflows/deynu-review-notes.yml", __dir__))
    job = workflow.fetch("jobs").fetch("review_notes")
    job.fetch("steps").each do |step|
      # Runner receives the merged workflow, job and step environment.
      env = workflow.fetch("env", {}).merge(job.fetch("env", {})).merge(step.fetch("env", {}))
      script = step.fetch("run", "")
      refute env.key?("DEYNU_REVIEW_NOTES_TEXT")
      env.each_value { |value| refute_match(/inputs\s*(?:\.notes|\[['\"]notes['\"]\])/, value.to_s) }
      refute_match(/\$\{\{[^}]*inputs\s*(?:\.notes|\[['\"]notes['\"]\])/, script)
      # Runner prints the script and the already-evaluated step env before Ruby.
      # Evaluate a malicious notes expression if one is reintroduced so this
      # regression catches the pre-wrapper leak, not merely CLI stdout safety.
      evaluated = env.transform_values { |value| value.to_s.gsub("${{ inputs.notes }}", PRIVATE) }
      header = "Run #{script}\nenv:\n" + evaluated.map { |key, value| "  #{key}: #{value}" }.join("\n")
      refute_includes header, PRIVATE
    end
    assert_includes workflow_wrapper_source, 'ENV.fetch("GITHUB_EVENT_PATH")'
    refute_includes workflow_wrapper_source, 'ENV.fetch("DEYNU_REVIEW_NOTES_TEXT"'
  end

  def test_workflow_is_manual_main_fixed_environment_read_only_and_safe_env_only
    path = File.expand_path("../workflows/deynu-review-notes.yml", __dir__)
    workflow = YAML.load_file(path)
    trigger = workflow["on"] || workflow[true]
    assert_equal ["workflow_dispatch"], trigger.keys
    inputs = trigger.fetch("workflow_dispatch").fetch("inputs")
    assert_equal false, inputs.dig("apply", "default")
    assert_equal "boolean", inputs.dig("apply", "type")
    assert_equal({ "contents" => "read" }, workflow["permissions"])
    assert_equal "majia-asc-almanac-production-${{ github.repository }}", workflow.dig("concurrency", "group")
    job = workflow.dig("jobs", "review_notes")
    assert_equal "almanac-production", job["environment"]
    assert_equal "${{ github.ref == 'refs/heads/main' }}", job["if"]
    job["steps"].each do |step|
      refute_includes step.fetch("run", ""), "${{ inputs."
      refute_match(/submit-asc|build-ios|upload-artifact|prepare-existing|runtime-ios-release/, step.fetch("run", "") + step.fetch("uses", ""))
    end
    script = job["steps"].last["run"]
    assert_includes script, "Tempfile.create"
    assert_includes script, "file.chmod(0o600)"
    assert_includes script, 'ENV.delete("DEYNU_REVIEW_NOTES_TEXT")'
  end


end

Minitest.after_run do
  puts "DEYNU_REVIEW_NOTES_FAKE_TESTS_COMPLETED"
end
