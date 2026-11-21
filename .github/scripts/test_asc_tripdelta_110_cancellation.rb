# frozen_string_literal: true

require "minitest/autorun"
require_relative "lib/asc_tripdelta_110_cancellation"

class ASCTripDelta110CancellationTest < Minitest::Test
  C = MajiaCI::ASCTripDelta110Cancellation
  NewID = "bbbbbbbb-2222-4333-8444-555555555555"
  NewNumber = "7"
  AppPath = "/v1/apps/#{C::APP_ID}"
  Versions = "#{AppPath}/appStoreVersions"
  Submissions = "#{AppPath}/reviewSubmissions"
  Items = "/v1/reviewSubmissions/#{C::SUBMISSION_ID}/items"
  Batch = "/v1/reviewSubmissions/#{C::SUBMISSION_ID}"
  Pre = "#{AppPath}/preReleaseVersions"
  Builds = "/v1/preReleaseVersions/pre-1/builds"
  Uploads = "#{AppPath}/buildUploads"
  OldBuild = "/v1/builds/#{C::OLD_BUILD_ID}"
  OldLink = "/v1/appStoreVersions/#{C::VERSION_ID}/relationships/build"

  class Client
    attr_accessor :version_state, :submission_state, :patch_error, :on_patch, :on_gate, :gate_count
    attr_reader :calls, :routes

    def initialize(routes)
      @routes = routes
      @calls = []
      @version_state = "WAITING_FOR_REVIEW"
      @submission_state = "WAITING_FOR_REVIEW"
      @gate_count = 0
    end

    def paginate(path, query = nil)
      read(:paginate, path, query)
    end

    def get(path, query = nil)
      read(:get, path, query)
    end

    def patch(path, payload)
      @calls << [:patch, path, payload]
      raise @patch_error if @patch_error
      @on_patch&.call(self)
      @version_state = "DEVELOPER_REJECTED"
      @submission_state = "COMPLETE"
      { "data" => { "type" => "reviewSubmissions", "id" => C::SUBMISSION_ID } }
    end

    def read(method, path, query)
      @calls << [method, path, query]
      raise "unexpected endpoint" unless @routes.key?([method, path])
      if path == Pre
        @gate_count += 1
        @on_gate&.call(self)
      end
      response = @routes.fetch([method, path])
      raise response if response.is_a?(Exception)
      response = response.call(self) if response.respond_to?(:call)
      Marshal.load(Marshal.dump(response))
    end
  end

  def test_default_dry_run_verifies_new_upload_without_mutations
    client = fixture
    result = cancel(client)
    assert result.fetch("dry_run")
    assert result.fetch("ready_to_cancel")
    refute result.fetch("completed")
    refute result.fetch("cancel_requested")
    assert_empty patches(client)
    assert_equal "upload-independent-id", result.dig("replacement", "upload_id")
    assert_equal NewID, result.dig("replacement", "build_id")
    assert_equal NewNumber, result.dig("replacement", "build_number")
    query = client.calls.find { |method, path, _q| method == :paginate && path == Uploads }.last
    assert_equal "build", query.fetch("include")
    assert_includes query.fetch("fields[buildUploads]").split(","), "build"
    assert client.calls.all? { |method, _p, _q| %i[get paginate].include?(method) }
  end

  def test_execute_refreshes_replacement_gate_then_sends_only_one_precise_cancel_patch
    client = fixture
    result = cancel(client, execute: true)
    assert result.fetch("completed")
    assert result.fetch("cancel_requested")
    assert_equal 2, client.gate_count
    assert_equal [[:patch, Batch, { "data" => { "type" => "reviewSubmissions", "id" => C::SUBMISSION_ID,
                                               "attributes" => { "canceled" => true } } }]], patches(client)
    assert_equal({ "id" => C::OLD_BUILD_ID, "version" => "1" }, result.dig("after", "build"))
    assert_equal "DEVELOPER_REJECTED", result.dig("after", "version_state")
  end

  def test_in_review_can_be_cancelled
    client = fixture
    client.version_state = client.submission_state = "IN_REVIEW"
    assert cancel(client, execute: true).fetch("completed")
    assert_equal 1, patches(client).length
  end

  def test_already_completed_is_idempotent_without_new_gate_or_patch
    client = fixture
    client.version_state = "DEVELOPER_REJECTED"
    client.submission_state = "COMPLETE"
    result = cancel(client, execute: true)
    assert result.fetch("completed")
    assert result.fetch("no_op")
    assert_equal 0, client.gate_count
    assert_empty patches(client)
  end

  def test_canceling_polls_without_repeating_cancel_patch
    client = fixture
    client.submission_state = "CANCELING"
    polls = 0
    client.routes[[:get, Batch]] = lambda do |c|
      polls += 1
      if polls >= 3
        c.submission_state = "COMPLETE"
        c.version_state = "DEVELOPER_REJECTED"
      end
      { "data" => submission(c.submission_state) }
    end
    # Snapshot reads version before batch, so one further poll observes the final pair.
    result = cancel(client, execute: true, max_polls: 3)
    assert result.fetch("completed")
    assert result.fetch("no_op")
    assert_empty patches(client)
  end

  def test_bad_scope_and_old_build_changes_never_patch
    cases = {
      [:paginate, "/v1/apps"] => [resource("apps", "99999999", "bundleId" => C::BUNDLE_ID)],
      [:paginate, Submissions] => [resource("reviewSubmissions", C::SUBMISSION_ID, "platform" => "MAC_OS")],
      [:paginate, Versions] => [version("WAITING_FOR_REVIEW").merge("id" => "wrong-version")],
      [:get, OldLink] => { "data" => { "type" => "builds", "id" => NewID } },
      [:get, OldBuild] => { "data" => resource("builds", C::OLD_BUILD_ID, "version" => "2") }
    }
    cases.each do |route, response|
      client = fixture
      client.routes[route] = response
      assert_rejected(client)
    end
  end

  def test_new_build_state_expiry_number_id_and_scope_are_strict
    [
      new_build.merge("attributes" => { "version" => NewNumber, "processingState" => "PROCESSING", "expired" => false }),
      new_build.merge("attributes" => { "version" => NewNumber, "processingState" => "VALID", "expired" => true }),
      new_build.merge("id" => "cccccccc-2222-4333-8444-555555555555"),
      new_build.merge("attributes" => { "version" => "2", "processingState" => "VALID", "expired" => false }),
      new_build.merge("relationships" => { "app" => { "data" => { "type" => "apps", "id" => "99999999" } } })
    ].each do |build|
      client = fixture
      client.routes[[:paginate, Builds]] = [build]
      assert_rejected(client)
    end
  end

  def test_replacement_pre_release_requires_same_ios_marketing_version_and_unique_scope
    [[], [prerelease, prerelease], [prerelease.merge("attributes" => { "platform" => "MAC_OS", "version" => C::MARKETING_VERSION })],
     [prerelease.merge("attributes" => { "platform" => "IOS", "version" => "1.0.9" })],
     [prerelease.merge("relationships" => { "app" => { "data" => { "type" => "apps", "id" => "99999999" } } })]].each do |rows|
      client = fixture
      client.routes[[:paginate, Pre]] = rows
      assert_rejected(client)
    end
  end

  def test_upload_requires_complete_unique_tuple_and_explicit_new_build_link
    missing = upload
    missing.delete("relationships")
    wrong_link = upload.merge("relationships" => { "build" => { "data" => { "type" => "builds", "id" => C::OLD_BUILD_ID } } })
    processing = upload
    processing["attributes"]["state"] = { "state" => "PROCESSING" }
    wrong_version = upload
    wrong_version["attributes"]["cfBundleShortVersionString"] = "1.0.9"
    [[], [upload, upload], [missing], [wrong_link], [processing], [wrong_version]].each do |rows|
      client = fixture
      client.routes[[:paginate, Uploads]] = rows
      assert_rejected(client)
    end
  end

  def test_only_single_exact_version_item_and_no_other_material_may_be_cancelled
    extra = item
    extra["relationships"]["appEvent"] = { "data" => { "type" => "appEvents", "id" => "event-1" } }
    wrong = item
    wrong["relationships"]["appStoreVersion"]["data"]["id"] = "another-version"
    unknown = item
    unknown["relationships"]["futureResource"] = { "data" => nil }
    [[], [item, item], [extra], [wrong], [unknown]].each do |rows|
      client = fixture
      client.routes[[:paginate, Items]] = rows
      assert_rejected(client)
    end
  end

  def test_links_only_material_relationship_uses_only_fixed_same_api_path
    client = fixture
    linked = item
    path = "/v1/reviewSubmissionItems/item-1/relationships/appEvent"
    linked["relationships"]["appEvent"] = { "links" => { "self" => path } }
    client.routes[[:paginate, Items]] = [linked]
    client.routes[[:get, path]] = { "data" => nil }
    assert cancel(client).fetch("ready_to_cancel")
    linked["relationships"]["appEvent"]["links"]["self"] = "https://evil.example/#{path}"
    client = fixture
    client.routes[[:paginate, Items]] = [linked]
    assert_rejected(client)
  end

  def test_replacement_is_revalidated_before_patch
    client = fixture
    client.on_gate = lambda do |c|
      if c.gate_count == 2
        bad = new_build
        bad["attributes"]["expired"] = true
        c.routes[[:paginate, Builds]] = [bad]
      end
    end
    assert_rejected(client)
    assert_equal 2, client.gate_count
  end

  def test_patch_timeout_does_not_retry_and_attaches_safe_readback_evidence
    client = fixture
    client.patch_error = MajiaCI::ASCStatusError.new("PRIVATE_P8_AND_CONTACT_CANARY")
    error = assert_raises(MajiaCI::ASCCancellationError) { cancel(client, execute: true) }
    assert_equal 1, patches(client).length
    assert error.evidence.fetch("cancel_requested")
    refute error.evidence.fetch("completed")
    refute_includes error.message, "PRIVATE"
    refute_includes JSON.generate(error.evidence), "PRIVATE"
  end

  def test_timeout_and_changed_old_build_after_patch_fail_without_second_patch
    client = fixture
    client.on_patch = ->(c) { c.routes[[:get, OldLink]] = { "data" => { "type" => "builds", "id" => NewID } } }
    error = assert_raises(MajiaCI::ASCCancellationError) { cancel(client, execute: true) }
    assert_equal 1, patches(client).length
    refute error.evidence.fetch("completed")
  end

  def test_canceling_timeout_is_bounded_and_does_not_patch
    client = fixture
    client.submission_state = "CANCELING"
    error = assert_raises(MajiaCI::ASCCancellationError) { cancel(client, execute: true, max_polls: 2) }
    assert_empty patches(client)
    refute error.evidence.fetch("completed")
    assert_match(/polling limit/, error.message)
  end

  def test_unknown_remote_errors_are_sanitized_and_keep_json_evidence
    client = fixture
    client.routes[[:paginate, Uploads]] = MajiaCI::ASCPermissionError.new("P8_CANARY")
    error = assert_rejected(client)
    refute_includes error.message, "P8_CANARY"
    assert_equal C::VERSION_ID, error.evidence.fetch("requested_version_id")
    refute_includes JSON.generate(error.evidence), "P8_CANARY"
  end

  def test_input_gate_rejects_old_id_non_uuid_old_number_and_non_boolean_execute_before_get
    [
      { replacement_build_id: C::OLD_BUILD_ID }, { replacement_build_id: "../bad" },
      { replacement_build_number: "1" }, { replacement_build_number: "02" },
      { replacement_build_number: 2 }, { execute: "true" }, { max_polls: 0 }
    ].each do |args|
      client = fixture
      assert_raises(MajiaCI::ASCCancellationError) { cancel(client, **args) }
      assert_empty client.calls
    end
  end

  private

  def cancel(client, **args)
    C.cancel(client: client, replacement_build_id: NewID, replacement_build_number: NewNumber,
             poll_seconds: 0, sleeper: ->(_n) {}, **args)
  end

  def patches(client)
    client.calls.select { |method, _path, _payload| method == :patch }
  end

  def assert_rejected(client)
    error = assert_raises(MajiaCI::ASCCancellationError) { cancel(client, execute: true) }
    assert_empty patches(client)
    refute error.evidence.fetch("completed")
    error
  end

  def fixture
    client = Client.new({})
    client.routes.merge!({
      [:paginate, "/v1/apps"] => [resource("apps", C::APP_ID, "bundleId" => C::BUNDLE_ID)],
      [:paginate, Submissions] => [submission("WAITING_FOR_REVIEW")],
      [:paginate, Versions] => ->(c) { [version(c.version_state)] },
      [:get, Batch] => ->(c) { { "data" => submission(c.submission_state) } },
      [:get, OldLink] => { "data" => { "type" => "builds", "id" => C::OLD_BUILD_ID } },
      [:get, OldBuild] => { "data" => resource("builds", C::OLD_BUILD_ID, "version" => "1") },
      [:paginate, Items] => [item], [:paginate, Pre] => [prerelease],
      [:paginate, Builds] => [new_build], [:paginate, Uploads] => [upload]
    })
    client
  end

  def resource(type, id, attributes)
    { "type" => type, "id" => id, "attributes" => attributes }
  end

  def version(state)
    resource("appStoreVersions", C::VERSION_ID, "platform" => "IOS", "versionString" => C::MARKETING_VERSION, "appVersionState" => state)
  end

  def submission(state)
    resource("reviewSubmissions", C::SUBMISSION_ID, "platform" => "IOS", "state" => state)
  end

  def prerelease
    resource("preReleaseVersions", "pre-1", "platform" => "IOS", "version" => C::MARKETING_VERSION)
  end

  def new_build
    resource("builds", NewID, "version" => NewNumber, "processingState" => "VALID", "expired" => false)
  end

  def upload
    resource("buildUploads", "upload-independent-id", "platform" => "IOS", "cfBundleShortVersionString" => C::MARKETING_VERSION,
             "cfBundleVersion" => NewNumber, "state" => { "state" => "COMPLETE" }).merge(
      "relationships" => { "build" => { "data" => { "type" => "builds", "id" => NewID } } }
    )
  end

  def item
    resource("reviewSubmissionItems", "item-1", "state" => "READY_FOR_REVIEW").merge(
      "relationships" => { "appStoreVersion" => { "data" => { "type" => "appStoreVersions", "id" => C::VERSION_ID } }, "appEvent" => { "data" => nil } }
    )
  end
end
