# frozen_string_literal: true

require "minitest/autorun"
require_relative "lib/asc_review_cancellation"

class CancellationClient
  C = MajiaCI::ASCReviewCancellation
  attr_reader :calls
  attr_accessor :app, :version_id, :version_number, :platform, :items, :submissions, :patch_error, :read_error, :build_id, :relationship_data

  def initialize(states: [["WAITING_FOR_REVIEW", "WAITING_FOR_REVIEW"], ["COMPLETE", "DEVELOPER_REJECTED"]], target: C::TRIPDELTA_108)
    @calls = []
    @states = states
    @poll = 0
    @app = { "id" => C::APP_ID, "attributes" => { "bundleId" => C::BUNDLE_ID } }
    @version_id, @version_number, @platform = target.fetch(:version_id), target.fetch(:version), "IOS"
    @expected_version_id = @version_id
    @submission_id = target.fetch(:submission_id)
    @build_id, @build_number = target.fetch(:build_id, "build-1"), target.fetch(:build_number, "1")
    @relationship_data = nil
    @submissions = [{ "type" => "reviewSubmissions", "id" => @submission_id, "attributes" => { "platform" => "IOS" } }]
    @items = [{ "type" => "reviewSubmissionItems", "id" => "item-1", "relationships" =>
      C::ITEM_RELATIONSHIPS.to_h { |key| [key, { "data" => key == "appStoreVersion" ? { "type" => "appStoreVersions", "id" => @expected_version_id } : nil }] } }]
  end

  def version
    { "type" => "appStoreVersions", "id" => version_id, "attributes" => {
      "versionString" => version_number, "platform" => platform, "appVersionState" => @states[@poll][1]
    } }
  end

  def paginate(path, query = nil)
    @calls << [:paginate, path, query]
    return [app] if path == "/v1/apps"
    return [version] if path == "/v1/apps/#{C::APP_ID}/appStoreVersions"
    return submissions if path == "/v1/apps/#{C::APP_ID}/reviewSubmissions"
    return items if path == "/v1/reviewSubmissions/#{@submission_id}/items"

    raise "unexpected GET list #{path}"
  end

  def get(path, query = nil)
    @calls << [:get, path, query]
    case path
    when "/v1/appStoreVersions/#{@expected_version_id}"
      raise read_error if read_error
      @poll = [@poll + 1, @states.length - 1].min
      { "data" => version }
    when "/v1/reviewSubmissions/#{@submission_id}"
      { "data" => { "type" => "reviewSubmissions", "id" => @submission_id,
                    "attributes" => { "platform" => "IOS", "state" => @states[@poll][0] } } }
    when "/v1/appStoreVersions/#{@expected_version_id}/relationships/build"
      { "data" => { "id" => build_id } }
    when "/v1/builds/#{build_id}"
      { "data" => { "id" => build_id, "attributes" => { "version" => @build_number } } }
    when %r{\A/v1/reviewSubmissionItems/item-1/relationships/} then { "data" => relationship_data }
    else raise "unexpected GET #{path}"
    end
  end

  def patch(path, payload)
    @calls << [:patch, path, payload]
    raise patch_error if patch_error

    {}
  end
end

class ASCReviewCancellationTest < Minitest::Test
  C = MajiaCI::ASCReviewCancellation
  E = MajiaCI::ASCCancellationError

  def cancel(client, **options)
    C.cancel(client: client, max_polls: 3, poll_seconds: 0, sleeper: ->(_) {}, **options)
  end

  def patches(client)
    client.calls.select { |method, *_| method == :patch }
  end

  def assert_blocked(client)
    error = assert_raises(E) { cancel(client) }
    assert_equal false, error.evidence["completed"]
    assert_empty patches(client)
  end

  def test_success_only_patches_exact_submission_and_preserves_build
    client = CancellationClient.new
    result = cancel(client)
    assert result["completed"]
    assert result["cancel_requested"]
    refute result["no_op"]
    assert_equal result["before"]["build"], result["after"]["build"]
    assert_equal "DEVELOPER_REJECTED", result["after"]["version_state"]
    assert_equal [[:patch, "/v1/reviewSubmissions/#{C::SUBMISSION_ID}", {
      "data" => { "type" => "reviewSubmissions", "id" => C::SUBMISSION_ID, "attributes" => { "canceled" => true } }
    }]], patches(client)
    assert client.calls.all? { |method, *_| %i[get paginate patch].include?(method) }
  end

  def test_tripdelta_111_refuses_a_different_linked_build
    client = CancellationClient.new(target: C::TRIPDELTA_111)
    client.build_id = "wrong-build"
    error = assert_raises(E) { cancel(client, target: C::TRIPDELTA_111) }
    assert_match(/linked build does not match/, error.message)
    assert_empty patches(client)
  end

  def test_tripdelta_111_cancels_only_its_submitted_batch
    target = C::TRIPDELTA_111
    client = CancellationClient.new(target: target)
    result = cancel(client, target: target)
    assert result["completed"]
    assert_equal target.fetch(:build_id), result.dig("after", "build", "id")
    assert_equal ["/v1/reviewSubmissions/#{target.fetch(:submission_id)}"], patches(client).map { |_, path, _| path }
  end

  def test_existing_canceling_submission_is_polled_without_second_patch
    client = CancellationClient.new(states: [["CANCELING", "WAITING_FOR_REVIEW"], ["CANCELING", "WAITING_FOR_REVIEW"], ["COMPLETE", "DEVELOPER_REJECTED"]])
    result = cancel(client)
    assert result["completed"]
    assert result["no_op"]
    assert_empty patches(client)
  end

  def test_already_canceled_is_a_read_only_no_op
    client = CancellationClient.new(states: [["COMPLETE", "DEVELOPER_REJECTED"]])
    result = cancel(client)
    assert result["completed"]
    assert result["no_op"]
    assert_empty patches(client)
  end

  def test_in_review_can_be_canceled
    client = CancellationClient.new(states: [["IN_REVIEW", "IN_REVIEW"], ["COMPLETE", "DEVELOPER_REJECTED"]])
    assert cancel(client)["completed"]
    assert_equal 1, patches(client).length
  end

  def test_wrong_app_bundle_version_id_version_number_and_platform_never_write
    changes = [->(c) { c.app["id"] = "other" }, ->(c) { c.app["attributes"]["bundleId"] = "other.bundle" },
               ->(c) { c.version_id = "wrong" }, ->(c) { c.version_number = "1.0.9" },
               ->(c) { c.platform = "MAC_OS" }, ->(c) { c.submissions.first["id"] = "wrong" }]
    changes.each do |change|
      client = CancellationClient.new
      change.call(client)
      assert_blocked(client)
    end
  end

  def test_multiple_or_missing_items_never_write
    [[], [1, 2]].each do |items|
      client = CancellationClient.new
      client.items = items
      assert_blocked(client)
    end
  end

  def test_wrong_version_linkage_and_item_type_never_write
    [->(c) { c.items.first["type"] = "apps" },
     ->(c) { c.items.first["relationships"]["appStoreVersion"]["data"]["id"] = "other" },
     ->(c) { c.items.first["relationships"]["appStoreVersion"]["data"]["type"] = "apps" }].each do |change|
      client = CancellationClient.new
      change.call(client)
      assert_blocked(client)
    end
  end

  def test_every_other_material_or_missing_linkage_blocks_cancellation
    (C::ITEM_RELATIONSHIPS - ["appStoreVersion"]).each do |name|
      client = CancellationClient.new
      client.items.first["relationships"][name]["data"] = { "id" => "another-item" }
      assert_blocked(client)
      client.items.first["relationships"][name] = { "links" => { "related" => "unknown" } }
      assert_blocked(client)
    end
    client = CancellationClient.new
    client.items.first["relationships"]["futureResource"] = { "data" => nil }
    assert_blocked(client)
  end

  def test_timeout_keeps_requested_and_last_observed_state_without_retry
    client = CancellationClient.new(states: [["WAITING_FOR_REVIEW", "WAITING_FOR_REVIEW"], ["CANCELING", "WAITING_FOR_REVIEW"]])
    error = assert_raises(E) { cancel(client) }
    assert error.evidence["cancel_requested"]
    refute error.evidence["completed"]
    assert_equal "CANCELING", error.evidence["after"]["submission_state"]
    assert_equal 1, patches(client).length
  end

  def test_patch_timeout_does_not_retry_and_records_readback
    client = CancellationClient.new
    client.patch_error = IOError.new("timeout")
    error = assert_raises(E) { cancel(client) }
    assert_equal 1, patches(client).length
    assert_equal "DEVELOPER_REJECTED", error.evidence["after"]["version_state"]
    refute error.evidence["completed"]
  end

  def test_patch_and_readback_failure_keep_recoverable_evidence
    client = CancellationClient.new
    client.patch_error = IOError.new("timeout")
    client.read_error = IOError.new("read timeout")
    error = assert_raises(E) { cancel(client) }
    assert error.evidence["readback_failed"]
    assert_equal 1, patches(client).length
  end

  def test_complete_but_released_and_unknown_states_are_not_canceled
    [["COMPLETE", "READY_FOR_DISTRIBUTION"], ["COMPLETING", "IN_REVIEW"], ["UNKNOWN", "WAITING_FOR_REVIEW"]].each do |states|
      assert_blocked(CancellationClient.new(states: [states]))
    end
  end

  def test_polling_limits_are_validated_before_network_access
    client = CancellationClient.new
    assert_raises(E) { C.cancel(client: client, max_polls: 0) }
    assert_empty client.calls
  end
  def test_optional_omitted_materials_do_not_block_exact_version
    client = CancellationClient.new
    client.items.first["relationships"].select! { |name, _| name == "appStoreVersion" }
    result = cancel(client)
    assert result["completed"]
    assert_equal "item-1", result["verified_item"]["id"]
    query = client.calls.find { |method, path, _| method == :paginate && path.end_with?("/items") }.last
    assert_equal "appStoreVersion", query["include"]
    refute query.key?("fields[reviewSubmissionItems]")
  end

  def test_links_only_known_relationship_is_read_back_from_fixed_apple_path
    client = CancellationClient.new
    client.items.first["relationships"]["appEvent"] = {
      "links" => { "self" => "https://api.appstoreconnect.apple.com/v1/reviewSubmissionItems/item-1/relationships/appEvent" }
    }
    assert cancel(client)["completed"]
    assert client.calls.any? { |method, path, _| method == :get && path == "/v1/reviewSubmissionItems/item-1/relationships/appEvent" }
  end

  def test_links_only_nonempty_resource_and_untrusted_link_never_write
    client = CancellationClient.new
    client.items.first["relationships"]["appEvent"] = {
      "links" => { "self" => "/v1/reviewSubmissionItems/item-1/relationships/appEvent" }
    }
    client.relationship_data = { "id" => "other-resource" }
    assert_blocked(client)
    client.relationship_data = nil
    client.items.first["relationships"]["appEvent"]["links"]["self"] = "https://example.com/secret"
    assert_blocked(client)
    refute client.calls.any? { |_, path, _| path.include?("example.com") }
  end

  def test_workflow_and_cli_are_fixed_to_authorized_main_production_scope
    workflow = File.read(File.join(__dir__, "../workflows/tripdelta-cancel-108-review.yml"))
    cli = File.read(File.join(__dir__, "cancel-tripdelta-108-review.rb"))
    assert_includes workflow, "workflow_dispatch:"
    refute_includes workflow, "inputs:"
    assert_includes workflow, "github.ref == 'refs/heads/main'"
    assert_includes workflow, "environment: tripdelta-production"
    assert_includes workflow, "contents: read"
    assert_includes workflow, "cancel-in-progress: false"
    assert_equal ["--output PATH", "--github-output PATH", "--github-summary PATH"], cli.scan(/parser.on\("([^"]+)"\)/).flatten
    assert_includes cli, 'options = { version: "1.0.8" }'
    refute_includes workflow, "IOS_DISTRIBUTION_P12"
    assert_includes cli, "com.tripdelta.lite.app"
    assert_includes cli, "cancellation.cancel(client: client, target: target)"
    new_workflow = File.read(File.join(__dir__, "../workflows/tripdelta-cancel-111-review.yml"))
    assert_includes new_workflow, "--version 1.0.11"
    assert_includes new_workflow, "environment: tripdelta-production"
    refute_includes workflow, "--version"
  end

  def test_submission_must_belong_uniquely_to_target_app_with_correct_type_and_platform
    [[], [{ "id" => C::SUBMISSION_ID, "type" => "apps", "attributes" => { "platform" => "IOS" } }],
     [{ "id" => C::SUBMISSION_ID, "type" => "reviewSubmissions", "attributes" => { "platform" => "MAC_OS" } }]].each do |resources|
      client = CancellationClient.new
      client.submissions = resources
      assert_blocked(client)
    end
    client = CancellationClient.new
    client.submissions *= 2
    assert_blocked(client)
  end

  def test_ownership_uses_scoped_app_list_without_unsupported_relationship_operation
    client = CancellationClient.new
    assert cancel(client)["completed"]
    lookup = client.calls.find { |method, path, _| method == :paginate && path == "/v1/apps/#{C::APP_ID}/reviewSubmissions" }
    assert_equal({ "filter[platform]" => "IOS", "limit" => "200" }, lookup.last)
    refute client.calls.any? { |_, path, _| path == "/v1/reviewSubmissions/#{C::SUBMISSION_ID}/relationships/app" }
    assert_raises(RuntimeError) { CancellationClient.new.get("/v1/reviewSubmissions/#{C::SUBMISSION_ID}/relationships/app") }
    assert_raises(RuntimeError) { CancellationClient.new.paginate("/v1/apps/other/reviewSubmissions") }
  end

end
