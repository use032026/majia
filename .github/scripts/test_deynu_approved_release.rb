# frozen_string_literal: true

require "minitest/autorun"
require "open3"
require "tmpdir"
require_relative "lib/deynu_approved_release"

class DeynuApprovedReleaseTest < Minitest::Test
  Release = MajiaCI::DeynuApprovedRelease

  class FakeClient
    attr_reader :calls
    attr_accessor :app, :versions, :relationship, :build, :post_result, :after_result

    def initialize
      @calls = []
      @app = { "data" => { "type" => "apps", "id" => Release::APP_ID,
                           "attributes" => { "bundleId" => Release::BUNDLE_ID } } }
      version = { "type" => "appStoreVersions", "id" => Release::VERSION_ID,
                  "attributes" => { "platform" => "IOS", "versionString" => "1.0.2",
                                    "appVersionState" => "PENDING_DEVELOPER_RELEASE", "releaseType" => "MANUAL" } }
      @versions = [version]
      @relationship = { "data" => { "type" => "builds", "id" => Release::BUILD_ID } }
      @build = { "data" => { "type" => "builds", "id" => Release::BUILD_ID,
                             "attributes" => { "version" => "1", "processingState" => "VALID", "expired" => false } } }
      @post_result = { "data" => { "type" => "appStoreVersionReleaseRequests", "id" => "request-102" } }
      @after_result = { "data" => Marshal.load(Marshal.dump(version)) }
    end

    def get(path, query = nil)
      @calls << [:get, path, query]
      result = case path
               when "/v1/apps/#{Release::APP_ID}" then app
               when "#{Release::VERSION_PATH}/relationships/build" then relationship
               when "/v1/builds/#{Release::BUILD_ID}" then build
               when Release::VERSION_PATH then after_result
               else raise "unexpected GET"
               end
      raise result if result.is_a?(Exception)

      result
    end

    def paginate(path, query)
      raise "wrong app scope" unless path == "/v1/apps/#{Release::APP_ID}/appStoreVersions"

      @calls << [:paginate, path, query]
      versions
    end

    def post_created(path, payload)
      @calls << [:post_created, path, payload]
      raise post_result if post_result.is_a?(Exception)

      post_result
    end
  end

  def setup
    @client = FakeClient.new
    @checkpoints = []
  end

  def run_release(**options)
    Release.release(client: @client, execute: true,
                    checkpoint: ->(value) { @checkpoints << Marshal.load(Marshal.dump(value)) }, **options)
  end

  def posts
    @client.calls.select { |method, _path, _payload| method == :post_created }
  end

  def after_reads
    @client.calls.count { |method, path, _query| method == :get && path == Release::VERSION_PATH }
  end

  def test_single_created_request_checkpoints_intent_and_keeps_distribution_separate
    result = run_release
    assert_nil result["error_code"]
    assert_equal true, result["request_accepted"]
    assert_equal "request-102", result["release_request_id"]
    assert_equal false, result["distribution_ready"]
    assert_equal true, @checkpoints.first["post_attempted"]
    assert_equal false, @checkpoints.first["request_accepted"]
    assert_equal 1, posts.length
    assert_equal 1, after_reads
    assert_equal({ "data" => { "type" => "appStoreVersionReleaseRequests", "relationships" => {
      "appStoreVersion" => { "data" => { "type" => "appStoreVersions", "id" => Release::VERSION_ID } }
    } } }, posts.first.last)
  end

  def test_default_is_read_only_and_repeated_workflow_attempt_cannot_write
    result = Release.release(client: @client)
    assert_equal "dry_run", result["no_op_reason"]
    assert_empty posts
    result = run_release(run_attempt: "2")
    assert_equal "workflow_attempt_not_first", result["no_op_reason"]
    assert_equal false, result["post_attempted"]
    assert_empty posts
  end

  def test_checkpoint_failure_prevents_the_post
    result = Release.release(client: @client, execute: true, checkpoint: ->(_value) { raise IOError })
    assert result["error_code"]
    assert_equal false, result["post_attempted"]
    assert_empty posts
    assert_equal 0, after_reads
  end

  def test_exact_identity_and_valid_unexpired_build_are_mandatory
    mutations = [
      -> { @client.app["data"]["id"] = "other" },
      -> { @client.app["data"]["attributes"]["bundleId"] = "other.bundle" },
      -> { @client.versions.first["id"] = "other-version" },
      -> { @client.versions.first["attributes"]["platform"] = "MAC_OS" },
      -> { @client.versions.first["attributes"]["versionString"] = "1.0.3" },
      -> { @client.versions << @client.versions.first.dup },
      -> { @client.relationship["data"]["id"] = "other-build" },
      -> { @client.build["data"]["id"] = "other-build" },
      -> { @client.build["data"]["attributes"]["version"] = "2" },
      -> { @client.build["data"]["attributes"]["processingState"] = "PROCESSING" },
      -> { @client.build["data"]["attributes"]["expired"] = true },
      -> { @client.build["data"]["attributes"].delete("expired") }
    ]
    mutations.each do |mutate|
      @client = FakeClient.new
      mutate.call
      assert run_release["error_code"]
      assert_empty posts
    end
  end

  def test_only_pending_manual_can_write_and_ready_identity_is_no_op
    %w[PROCESSING_FOR_DISTRIBUTION PROCESSING_FOR_APP_STORE IN_REVIEW UNKNOWN].each do |state|
      @client = FakeClient.new
      @client.versions.first["attributes"]["appVersionState"] = state
      assert_equal "version_not_pending_manual_release", run_release["error_code"]
      assert_empty posts
    end
    @client = FakeClient.new
    @client.versions.first["attributes"]["releaseType"] = "AFTER_APPROVAL"
    assert run_release["error_code"]
    assert_empty posts
    Release::READY_STATES.each do |state|
      @client = FakeClient.new
      @client.versions.first["attributes"]["appVersionState"] = state
      result = run_release
      assert_equal "already_distributed", result["no_op_reason"]
      assert_equal true, result["distribution_ready"]
      assert_empty posts
    end
  end

  def test_post_errors_and_ambiguous_responses_never_retry_or_imply_success
    outcomes = [Timeout::Error.new("token=secret"), MajiaCI::ASCStatusError.new("HTTP 403 secret"),
                MajiaCI::ASCStatusError.new("HTTP 500 secret"), JSON::ParserError.new("secret"), {},
                { "data" => { "type" => "wrong", "id" => "id" } },
                { "data" => { "type" => "appStoreVersionReleaseRequests", "id" => "" } }]
    outcomes.each do |outcome|
      @client = FakeClient.new
      @client.post_result = outcome
      @client.after_result["data"]["attributes"]["appVersionState"] = "READY_FOR_DISTRIBUTION"
      result = run_release
      assert result["error_code"]
      assert_equal false, result["request_accepted"]
      assert_equal true, result["distribution_ready"]
      assert_equal 1, posts.length
      assert_equal 1, after_reads
      refute_includes JSON.generate(result), "secret"
      if outcome.is_a?(Exception) && (status = outcome.message.match(/\bHTTP (\d{3})\b/))
        assert_equal status[1].to_i, result["post_http_status"]
      else
        refute result.key?("post_http_status")
      end
    end
  end

  def test_accepted_request_followed_by_processing_or_failed_snapshot_is_not_distribution
    @client.after_result["data"]["attributes"]["appVersionState"] = "PROCESSING_FOR_DISTRIBUTION"
    result = run_release
    assert_equal true, result["request_accepted"]
    assert_equal false, result["distribution_ready"]
    @client = FakeClient.new
    @client.after_result = Timeout::Error.new("secret")
    result = run_release
    assert_equal true, result["request_accepted"]
    assert_equal "post_snapshot_failed", result["error_code"]
    assert_equal false, result["distribution_ready"]
    assert_equal 1, posts.length
    assert_equal 1, after_reads
  end

  def test_accepted_request_can_observe_ready_but_a_failed_request_remains_failed
    @client.after_result["data"]["attributes"]["appVersionState"] = "READY_FOR_DISTRIBUTION"
    result = run_release
    assert_equal true, result["request_accepted"]
    assert_equal true, result["distribution_ready"]
    assert_nil result["error_code"]
    assert_equal 1, posts.length
    assert_equal 1, after_reads

    @client = FakeClient.new
    @client.post_result = Timeout::Error.new("secret")
    @client.after_result = MajiaCI::ASCStatusError.new("HTTP403 secret")
    result = run_release
    assert_equal "release_request_unconfirmed", result["error_code"]
    assert_equal "read_failed", result["post_snapshot_error"]
    assert_equal false, result["request_accepted"]
    assert_equal false, result["distribution_ready"]
    assert_equal 1, posts.length
    assert_equal 1, after_reads
  end

  def test_snapshot_with_wrong_identity_is_not_accepted_as_distribution
    @client.after_result["data"]["id"] = "wrong-version"
    @client.after_result["data"]["attributes"]["appVersionState"] = "READY_FOR_DISTRIBUTION"
    result = run_release
    assert_equal true, result["request_accepted"]
    assert_equal "version_identity_mismatch", result["error_code"]
    assert_equal false, result["distribution_ready"]
    assert_equal 1, posts.length
    assert_equal 1, after_reads
  end

  def test_cli_wrong_bundle_stops_before_auth_and_writes_redacted_failure
    Dir.mktmpdir do |directory|
      output = File.join(directory, "release.json")
      command = File.expand_path("release-deynu-approved.rb", __dir__)
      stdout, stderr, status = Open3.capture3(
        { "IOS_BUNDLE_ID" => "other.bundle", "ASC_API_KEY_P8" => "secret-marker" },
        RbConfig.ruby, command, "--output", output
      )
      refute status.success?
      result = JSON.parse(File.read(output))
      assert_equal "invalid_configuration_or_evidence_io", result["error_code"]
      assert_equal false, result["post_attempted"]
      refute_includes [stdout, stderr, File.read(output)].join, "secret-marker"
    end
  end
end
