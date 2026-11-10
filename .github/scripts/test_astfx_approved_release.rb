# frozen_string_literal: true

require "minitest/autorun"
require_relative "lib/astfx_approved_release"

class ASTFXApprovedReleaseTest < Minitest::Test
  Target = MajiaCI::ASTFXApprovedRelease::TARGET
  AppId = "6827824646"
  VersionId = "d4bbfe6f-612a-42a6-a6dc-74781d92baca"
  BuildId = "54710387-f2b5-4402-abc0-56969afeccd5"
  VersionPath = "/v1/appStoreVersions/#{VersionId}"

  class FakeClient
    attr_reader :events
    attr_accessor :bundle, :build_id, :expired, :processing, :state, :release_type

    def initialize
      @events = []
      @bundle = "com.astfx.lite"
      @build_id = BuildId
      @expired = false
      @processing = "VALID"
      @state = "PENDING_DEVELOPER_RELEASE"
      @release_type = "MANUAL"
    end

    def get(path, _query = nil)
      @events << [:get, path]
      data = case path
             when "/v1/apps/#{AppId}"
               resource("apps", AppId, "bundleId" => bundle)
             when "#{VersionPath}/relationships/build"
               resource("builds", build_id, {})
             when "/v1/builds/#{BuildId}"
               resource("builds", BuildId, "version" => "1", "processingState" => processing, "expired" => expired)
             when VersionPath
               version("PROCESSING_FOR_DISTRIBUTION")
             else
               raise "unexpected GET"
             end
      { "data" => data }
    end

    def paginate(path, query)
      unless path == "/v1/apps/#{AppId}/appStoreVersions" &&
             query["filter[platform]"] == "IOS" && query["filter[versionString]"] == "1.0.2"
        raise "unexpected listing request"
      end

      @events << [:paginate, path]
      [version(state)]
    end

    def post_created(path, payload)
      @events << [:post, path, payload]
      { "data" => resource("appStoreVersionReleaseRequests", "release-1", {}) }
    end

    private

    def version(version_state)
      resource("appStoreVersions", VersionId, {
        "platform" => "IOS", "versionString" => "1.0.2", "appVersionState" => version_state,
        "releaseType" => release_type
      })
    end

    def resource(type, id, attributes)
      { "type" => type, "id" => id, "attributes" => attributes }
    end
  end

  def test_default_and_repeated_workflow_attempt_are_read_only
    client = FakeClient.new
    first = Target.release(client: client)
    again = Target.release(client: client, execute: true, run_attempt: "2")
    assert_equal "dry_run", first["no_op_reason"]
    assert_equal "workflow_attempt_not_first", again["no_op_reason"]
    refute client.events.any? { |type, *_| type == :post }
  end

  def test_exact_target_checkpoints_one_post_and_reads_back
    client = FakeClient.new
    result = Target.release(
      client: client, execute: true,
      checkpoint: ->(summary) { client.events << [:checkpoint, summary["request_accepted"]] }
    )
    assert_equal [
      [:checkpoint, false],
      [:post, "/v1/appStoreVersionReleaseRequests", {
        "data" => {
          "type" => "appStoreVersionReleaseRequests",
          "relationships" => {
            "appStoreVersion" => { "data" => { "type" => "appStoreVersions", "id" => VersionId } }
          }
        }
      }],
      [:checkpoint, true],
      [:get, VersionPath]
    ], client.events.last(4)
    assert_equal true, result["request_accepted"]
    assert_equal false, result["distribution_ready"]
    assert_equal "PROCESSING_FOR_DISTRIBUTION", result.dig("post_snapshot", "app_version_state")
  end

  def test_wrong_bundle_build_or_state_cannot_publish
    [
      [:bundle, "com.almanac.lite", "app_identity_mismatch"],
      [:build_id, "different-build", "build_identity_mismatch"],
      [:expired, true, "build_not_exact_valid_unexpired"],
      [:processing, "PROCESSING", "build_not_exact_valid_unexpired"],
      [:state, "PREPARE_FOR_SUBMISSION", "version_not_pending_manual_release"],
      [:release_type, "AFTER_APPROVAL", "version_not_pending_manual_release"]
    ].each do |attribute, value, reason|
      client = FakeClient.new
      client.public_send("#{attribute}=", value)
      result = Target.release(client: client, execute: true, checkpoint: ->(_) {})
      assert_equal reason, result["error_code"]
      refute client.events.any? { |type, *_| type == :post }
    end
  end
end
