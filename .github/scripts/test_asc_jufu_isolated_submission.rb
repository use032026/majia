# frozen_string_literal: true

require "minitest/autorun"
require_relative "lib/asc_jufu_isolated_submission"

class ASCJufuIsolatedSubmissionTest < Minitest::Test
  S = MajiaCI::ASCJufuIsolatedSubmission
  AppPath = "/v1/apps/#{S::APP_ID}"
  Versions = "#{AppPath}/appStoreVersions"
  Submissions = "#{AppPath}/reviewSubmissions"
  BuildPath = "/v1/builds/#{S::BUILD_ID}"
  BuildLink = "/v1/appStoreVersions/#{S::VERSION_ID}/relationships/build"
  NewBatch = "new-isolated-batch"
  NewItem = "new-target-item"

  class Client
    attr_reader :calls, :batches, :items
    attr_accessor :app, :version, :build, :build_link, :fail_at, :on_mutation, :on_inventory, :inventory_reads, :create_id, :relationship_reads, :item_responses

    def initialize
      @calls = []
      @batches = {}
      @items = {}
      @inventory_reads = 0
      @create_id = NewBatch
      @relationship_reads = {}
      @item_responses = {}
    end

    def paginate(path, query = nil)
      @calls << [:paginate, path, query]
      raise MajiaCI::ASCStatusError, "REMOTE_PRIVATE_CANARY" if @fail_at == path
      case path
      when "/v1/apps" then [@app]
      when Versions then [@version]
      when Submissions
        @inventory_reads += 1
        @on_inventory&.call(self)
        @batches.values
      else
        match = path.match(%r{\A/v1/reviewSubmissions/([^/]+)/items\z})
        raise "unexpected paginate" unless match
        if @item_responses.key?(match[1])
          responses = @item_responses.fetch(match[1])
          responses.length > 1 ? responses.shift : responses.first
        else
          @items.fetch(match[1])
        end
      end.then { |value| Marshal.load(Marshal.dump(value)) }
    end

    def get(path, query = nil)
      @calls << [:get, path, query]
      raise MajiaCI::ASCStatusError, "REMOTE_PRIVATE_CANARY" if @fail_at == path
      value = case path
              when BuildLink then @build_link
              when BuildPath then @build
              else
                raise "unexpected GET endpoint"
              end
      { "data" => Marshal.load(Marshal.dump(value)) }
    end

    def post_created(path, payload)
      @calls << [:post_created, path, payload]
      raise MajiaCI::ASCStatusError, "REMOTE_PRIVATE_CANARY" if @fail_at == path
      response = if path == "/v1/reviewSubmissions"
                   batch = { "type" => "reviewSubmissions", "id" => @create_id,
                             "attributes" => { "platform" => "IOS", "state" => "READY_FOR_REVIEW" } }
                   @batches[@create_id] = batch
                   @items[@create_id] = []
                   batch
                 elsif path == "/v1/reviewSubmissionItems"
                   id = payload.dig("data", "relationships", "reviewSubmission", "data", "id")
                   raise "unsafe attach" unless id == @create_id
                   item = { "type" => "reviewSubmissionItems", "id" => NewItem, "attributes" => { "state" => "READY_FOR_REVIEW" },
                            "relationships" => S::RELATIONS.to_h { |name| [name, { "data" => name == "appStoreVersion" ? { "type" => "appStoreVersions", "id" => S::VERSION_ID } : nil }] } }
                   @items[id] << item
                   item
                 else raise "unexpected post"
                 end
      @on_mutation&.call(self, path)
      { "data" => Marshal.load(Marshal.dump(response)) }
    end

    def patch(path, payload)
      @calls << [:patch, path, payload]
      raise MajiaCI::ASCStatusError, "REMOTE_PRIVATE_CANARY" if @fail_at == path
      id = payload.dig("data", "id")
      raise "excluded mutation" if id == S::EXCLUDED_SUBMISSION_ID
      @batches.fetch(id).fetch("attributes")["state"] = "WAITING_FOR_REVIEW"
      @version.fetch("attributes")["appVersionState"] = "WAITING_FOR_REVIEW"
      @on_mutation&.call(self, path)
      { "data" => @batches.fetch(id) }
    end
  end

  def test_default_dry_run_reads_all_batches_and_never_mutates_unrelated_nonempty_draft
    client = fixture
    before = JSON.generate(client.batches.fetch(S::EXCLUDED_SUBMISSION_ID)) + JSON.generate(client.items.fetch(S::EXCLUDED_SUBMISSION_ID))
    result = S.run(client: client)
    assert_equal "dry_run_ready", result.fetch("phase")
    assert result.fetch("ready_to_submit")
    refute result.fetch("review_submitted")
    assert_empty mutations(client)
    assert client.calls.any? { |method, path, _| method == :paginate && path == "/v1/reviewSubmissions/#{S::EXCLUDED_SUBMISSION_ID}/items" }
    assert_nil result["review_submission"]
    assert_equal before, JSON.generate(client.batches.fetch(S::EXCLUDED_SUBMISSION_ID)) + JSON.generate(client.items.fetch(S::EXCLUDED_SUBMISSION_ID))
  end

  def test_execute_creates_new_batch_and_only_one_item_then_patches_only_that_batch
    client = fixture
    result = S.run(client: client, execute: true)
    assert result.fetch("review_submitted")
    assert_equal "submitted", result.fetch("phase")
    assert_equal NewBatch, result.fetch("created_submission_id")
    assert_equal NewItem, result.fetch("created_item_id")
    assert_equal [[:post_created, "/v1/reviewSubmissions"], [:post_created, "/v1/reviewSubmissionItems"], [:patch, "/v1/reviewSubmissions/#{NewBatch}"]], mutations(client).map { |method, path, _| [method, path] }
    assert_equal({ "submitted" => true }, mutations(client).last.last.dig("data", "attributes"))
    assert_equal "READY_FOR_REVIEW", client.batches.fetch(S::EXCLUDED_SUBMISSION_ID).dig("attributes", "state")
    assert_equal 1, client.items.fetch(S::EXCLUDED_SUBMISSION_ID).length
    assert_equal "AFTER_APPROVAL", result.dig("after", "release_type")
  end

  def test_target_only_ready_batch_can_be_reused_without_creating_or_attaching
    client = fixture
    add_target(client, "safe-existing", "READY_FOR_REVIEW")
    result = S.run(client: client, execute: true)
    assert result.fetch("review_submitted")
    assert_equal [[:patch, "/v1/reviewSubmissions/safe-existing"]], mutations(client).map { |m, p, _| [m, p] }
  end

  def test_accepted_same_target_is_idempotent_even_with_unrelated_ready_batch
    client = fixture
    add_target(client, "accepted", "WAITING_FOR_REVIEW")
    client.version["attributes"]["appVersionState"] = "WAITING_FOR_REVIEW"
    result = S.run(client: client, execute: true)
    assert result.fetch("review_submitted")
    assert result.fetch("no_op")
    assert_equal "already_submitted", result.fetch("phase")
    assert_empty mutations(client)
  end

  def test_unowned_empty_ready_batch_is_never_reused
    client = fixture
    client.batches["empty-existing"] = batch("empty-existing")
    client.items["empty-existing"] = []
    result = S.run(client: client, execute: true)
    assert_equal NewBatch, result.fetch("created_submission_id")
    assert_empty client.items.fetch("empty-existing")
    refute mutations(client).any? { |_m, _p, payload| payload.dig("data", "relationships", "reviewSubmission", "data", "id") == "empty-existing" }
  end

  def test_active_unrelated_batch_blocks_all_mutations
    %w[WAITING_FOR_REVIEW IN_REVIEW UNRESOLVED_ISSUES CANCELING COMPLETING].each do |state|
      client = fixture
      client.batches.fetch(S::EXCLUDED_SUBMISSION_ID)["attributes"]["state"] = state
      rejected(client)
    end
  end

  def test_excluded_batch_target_binding_is_never_reused_even_when_target_only
    client = fixture
    client.items[S::EXCLUDED_SUBMISSION_ID] = [target_item]
    error = rejected(client)
    assert_equal "excluded_batch_has_target_binding", error.evidence.fetch("errors").first.fetch("code")
  end

  def test_wrong_fixed_identity_platform_version_build_release_and_expiry_fail_before_mutation
    changes = [
      ->(c) { c.app["id"] = "999999" }, ->(c) { c.app["attributes"]["bundleId"] = "com.other.app" },
      ->(c) { c.version["id"] = "wrong-version" }, ->(c) { c.version["attributes"]["platform"] = "MAC_OS" },
      ->(c) { c.version["attributes"]["versionString"] = "1.0.4" }, ->(c) { c.version["attributes"]["releaseType"] = "MANUAL" },
      ->(c) { c.build_link["id"] = "other-build" }, ->(c) { c.build["attributes"]["processingState"] = "PROCESSING" },
      ->(c) { c.build["attributes"]["expired"] = true }, ->(c) { c.build["attributes"].delete("expired") },
      ->(c) { c.build["attributes"]["version"] = "2" }, ->(c) { c.version["type"] = "builds" }
    ]
    changes.each { |change| client = fixture; change.call(client); rejected(client) }
  end

  def test_target_batch_multiple_or_unknown_materials_are_never_submitted
    ["extra-item", "other-material", "unknown"].each do |mode|
      client = fixture
      add_target(client, "unsafe", "READY_FOR_REVIEW")
      case mode
      when "extra-item" then client.items["unsafe"] << event_item
      when "other-material" then client.items["unsafe"].first["relationships"]["appEvent"] = { "data" => { "type" => "appEvents", "id" => "event-1" } }
      else client.items["unsafe"].first["relationships"]["futureMaterial"] = { "data" => nil }
      end
      rejected(client)
    end
  end

  def test_minimal_complete_target_item_succeeds_without_any_optional_relationship_get
    client = fixture
    add_target(client, "safe-existing", "READY_FOR_REVIEW")
    client.items["safe-existing"].first["relationships"].select! { |name, _| name == "appStoreVersion" }
    result = S.run(client: client)
    assert result.fetch("ready_to_submit")
    refute client.calls.any? { |method, path, _| method == :get && path.start_with?("/v1/reviewSubmissionItems/") }
  end

  def test_declared_links_only_relation_is_resolved_only_by_one_complete_collection_reread
    client = fixture
    add_target(client, "safe-existing", "READY_FOR_REVIEW")
    links_only = target_item
    links_only["relationships"]["appEvent"] = { "links" => { "self" => "https://untrusted.invalid/no-follow" } }
    client.item_responses["safe-existing"] = [[links_only], [target_item]]
    assert S.run(client: client).fetch("ready_to_submit")
    reads = client.calls.select { |method, endpoint, _| method == :paginate && endpoint == "/v1/reviewSubmissions/safe-existing/items" }
    assert_equal 2, reads.length
    reads.each do |_method, _endpoint, query|
      assert_equal S::RELATIONS, query.fetch("include").split(",")
      assert_equal ["state"] + S::RELATIONS, query.fetch("fields[reviewSubmissionItems]").split(",")
    end
    refute client.calls.any? { |method, endpoint, _| method == :get && endpoint.include?("reviewSubmissionItems") }
  end

  def test_unresolved_links_only_or_missing_data_fail_without_any_relationship_get
    [{ "links" => { "self" => "https://evil.example/secret" } }, {}, { "links" => {} }].each do |relation|
      client = fixture
      add_target(client, "unsafe", "READY_FOR_REVIEW")
      client.items["unsafe"].first["relationships"]["appEvent"] = relation
      rejected(client)
      refute client.calls.any? { |method, endpoint, _| method == :get && endpoint.include?("reviewSubmissionItems") }
      assert_equal 2, client.calls.count { |method, endpoint, _| method == :paginate && endpoint == "/v1/reviewSubmissions/unsafe/items" }
    end
  end

  def test_missing_required_version_relation_and_null_untyped_material_are_rejected
    [:missing, :null].each do |mode|
      client = fixture
      add_target(client, "unsafe", "READY_FOR_REVIEW")
      relations = client.items["unsafe"].first["relationships"]
      mode == :missing ? relations.delete("appStoreVersion") : relations["appStoreVersion"] = { "data" => nil }
      rejected(client)
    end
  end

  def test_pre_submit_readback_rejects_new_batch_contamination
    client = fixture
    client.on_mutation = lambda do |c, path|
      c.items[NewBatch] << event_item if path == "/v1/reviewSubmissionItems"
    end
    error = assert_raises(MajiaCI::ASCJufuIsolatedSubmissionError) { S.run(client: client, execute: true) }
    assert_equal 2, mutations(client).length
    assert_equal NewBatch, error.evidence.fetch("created_submission_id")
    assert_equal "final_preflight", error.evidence.fetch("phase")
    assert_empty mutations(client).select { |method, _p, _| method == :patch }
  end

  def test_version_build_and_release_are_rechecked_before_final_patch
    client = fixture
    client.on_mutation = ->(c, path) { c.version["attributes"]["releaseType"] = "MANUAL" if path == "/v1/reviewSubmissionItems" }
    error = assert_raises(MajiaCI::ASCJufuIsolatedSubmissionError) { S.run(client: client, execute: true) }
    assert_equal NewBatch, error.evidence.fetch("created_submission_id")
    assert_empty mutations(client).select { |method, _p, _| method == :patch }
  end

  def test_failed_attach_retains_created_batch_receipt_without_editing_or_deleting_any_batch
    client = fixture
    client.fail_at = "/v1/reviewSubmissionItems"
    error = assert_raises(MajiaCI::ASCJufuIsolatedSubmissionError) { S.run(client: client, execute: true) }
    assert_equal NewBatch, error.evidence.fetch("created_submission_id")
    assert_equal "adding_only_target_item", error.evidence.fetch("phase")
    assert_empty client.items.fetch(NewBatch)
    assert_equal 2, mutations(client).length
    refute_includes JSON.generate(error.evidence), "REMOTE_PRIVATE_CANARY"
    refute_includes error.message, "REMOTE_PRIVATE_CANARY"
  end

  def test_post_timeout_and_patch_timeout_are_not_retried_and_preserve_requested_phase
    ["/v1/reviewSubmissions", "/v1/reviewSubmissions/#{NewBatch}"].each do |endpoint|
      client = fixture
      client.fail_at = endpoint
      error = assert_raises(MajiaCI::ASCJufuIsolatedSubmissionError) { S.run(client: client, execute: true) }
      assert_equal 1, mutations(client).count { |_m, path, _| path == endpoint }
      refute error.evidence.fetch("review_submitted")
      assert_equal "requested", error.evidence.fetch("requests").last.fetch("outcome")
      refute_includes JSON.generate(error.evidence), "REMOTE_PRIVATE_CANARY"
    end
  end

  def test_formal_acceptance_requires_real_submitted_state_and_preserves_item_scope
    client = fixture
    client.on_mutation = lambda do |c, path|
      c.batches[NewBatch]["attributes"]["state"] = "READY_FOR_REVIEW" if path == "/v1/reviewSubmissions/#{NewBatch}"
    end
    error = assert_raises(MajiaCI::ASCJufuIsolatedSubmissionError) { S.run(client: client, execute: true) }
    refute error.evidence.fetch("review_submitted")
    assert_equal "verifying_acceptance", error.evidence.fetch("phase")
  end

  def test_retry_after_failed_attach_never_claims_the_prior_empty_batch
    client = fixture
    client.fail_at = "/v1/reviewSubmissionItems"
    assert_raises(MajiaCI::ASCJufuIsolatedSubmissionError) { S.run(client: client, execute: true) }
    assert_empty client.items.fetch(NewBatch)
    client.fail_at = nil
    client.create_id = "second-new-isolated-batch"
    result = S.run(client: client, execute: true)
    assert_equal "second-new-isolated-batch", result.fetch("created_submission_id")
    assert_empty client.items.fetch(NewBatch)
    assert_equal "READY_FOR_REVIEW", client.batches.fetch(NewBatch).dig("attributes", "state")
    assert_equal "WAITING_FOR_REVIEW", client.batches.fetch("second-new-isolated-batch").dig("attributes", "state")
  end

  def test_new_active_batch_appearing_during_final_preflight_blocks_the_patch
    client = fixture
    client.on_mutation = lambda do |c, path|
      if path == "/v1/reviewSubmissionItems"
        c.batches["new-other-active"] = batch("new-other-active", "IN_REVIEW")
        c.items["new-other-active"] = [event_item]
      end
    end
    error = assert_raises(MajiaCI::ASCJufuIsolatedSubmissionError) { S.run(client: client, execute: true) }
    assert_equal "another_ios_review_batch_is_active", error.evidence.fetch("errors").first.fetch("code")
    assert_empty mutations(client).select { |method, _path, _payload| method == :patch }
  end

  def test_conflicting_direct_version_link_cannot_be_ignored_for_a_target_item
    client = fixture
    add_target(client, "inconsistent", "READY_FOR_REVIEW")
    client.batches["inconsistent"]["relationships"] = { "appStoreVersionForReview" => {
      "data" => { "type" => "appStoreVersions", "id" => "other-version" }
    } }
    rejected(client)
  end

  def test_fixed_parent_app_relationship_contradiction_fails_closed
    client = fixture
    client.version["relationships"] = { "app" => { "data" => { "type" => "apps", "id" => "other-app" } } }
    rejected(client)
  end

  def test_patch_accepted_but_readback_failure_retries_as_no_op_without_another_patch
    client = fixture
    client.on_mutation = lambda do |c, path|
      c.fail_at = Versions if path == "/v1/reviewSubmissions/#{NewBatch}"
    end
    error = assert_raises(MajiaCI::ASCJufuIsolatedSubmissionError) { S.run(client: client, execute: true) }
    refute error.evidence.fetch("review_submitted")
    refute error.evidence.fetch("ready_to_submit")
    assert_equal "verifying_acceptance", error.evidence.fetch("phase")
    assert_equal "request_failed", error.evidence.fetch("errors").first.fetch("kind")
    assert_equal "ASCStatusError", error.evidence.fetch("errors").first.fetch("error_class")
    client.fail_at = nil
    client.on_mutation = nil
    before_count = mutations(client).length
    result = S.run(client: client, execute: true)
    assert result.fetch("review_submitted")
    assert result.fetch("no_op")
    assert_equal "already_submitted", result.fetch("phase")
    assert_equal before_count, mutations(client).length
    assert_equal 1, mutations(client).count { |method, _path, _payload| method == :patch }
  end

  def test_item_exists_after_failed_readback_can_be_safely_reused_on_retry
    client = fixture
    client.on_mutation = lambda do |c, path|
      c.fail_at = Versions if path == "/v1/reviewSubmissionItems"
    end
    assert_raises(MajiaCI::ASCJufuIsolatedSubmissionError) { S.run(client: client, execute: true) }
    assert_equal 1, client.items.fetch(NewBatch).length
    assert_empty mutations(client).select { |method, _path, _payload| method == :patch }
    client.fail_at = nil
    client.on_mutation = nil
    result = S.run(client: client, execute: true)
    assert result.fetch("review_submitted")
    assert_equal NewBatch, result.dig("review_submission", "id")
    assert_equal 1, mutations(client).count { |method, path, _payload| method == :post_created && path == "/v1/reviewSubmissions" }
    assert_equal 1, mutations(client).count { |method, path, _payload| method == :post_created && path == "/v1/reviewSubmissionItems" }
  end

  def test_crossing_beijing_sunday_is_rechecked_immediately_before_patch
    client = fixture
    # Saturday 23:59 -> Sunday 00:01 in Beijing, while the run's initial timestamp stays Saturday.
    times = [Time.utc(2026, 11, 28, 15, 59), Time.utc(2026, 11, 28, 16, 1)]
    error = assert_raises(MajiaCI::ASCJufuIsolatedSubmissionError) do
      S.run(client: client, execute: true, checked_at: times.first, clock: -> { times.shift })
    end
    assert_equal "beijing_sunday_submission_blocked", error.evidence.fetch("errors").first.fetch("code")
    assert_equal "final_preflight", error.evidence.fetch("phase")
    assert_empty mutations(client).select { |method, _endpoint, _payload| method == :patch }
  end

  def test_sunday_dry_run_and_already_accepted_no_op_remain_read_only_and_allowed
    sunday = -> { Time.utc(2026, 11, 29, 1) }
    client = fixture
    assert S.run(client: client, clock: sunday).fetch("ready_to_submit")
    assert_empty mutations(client)
    add_target(client, "accepted", "WAITING_FOR_REVIEW")
    client.version["attributes"]["appVersionState"] = "WAITING_FOR_REVIEW"
    result = S.run(client: client, execute: true, clock: sunday)
    assert result.fetch("review_submitted")
    assert result.fetch("no_op")
    assert_empty mutations(client)
  end

  def test_sunday_execute_is_stopped_before_creating_any_batch
    client = fixture
    assert_raises(MajiaCI::ASCJufuIsolatedSubmissionError) do
      S.run(client: client, execute: true, clock: -> { Time.utc(2026, 11, 29, 1) })
    end
    assert_empty mutations(client)
  end

  def test_non_boolean_execute_fails_before_read
    client = fixture
    assert_raises(MajiaCI::ASCJufuIsolatedSubmissionError) { S.run(client: client, execute: "true") }
    assert_empty client.calls
  end

  private

  def mutations(client)
    client.calls.select { |method, _p, _| %i[post post_created patch delete].include?(method) }
  end

  def rejected(client)
    error = assert_raises(MajiaCI::ASCJufuIsolatedSubmissionError) { S.run(client: client, execute: true) }
    assert_empty mutations(client)
    refute error.evidence.fetch("review_submitted")
    error
  end

  def fixture
    c = Client.new
    c.app = resource("apps", S::APP_ID, "bundleId" => S::BUNDLE_ID)
    c.version = resource("appStoreVersions", S::VERSION_ID, "platform" => "IOS", "versionString" => S::MARKETING_VERSION,
                         "appVersionState" => "PREPARE_FOR_SUBMISSION", "releaseType" => "AFTER_APPROVAL")
    c.build = resource("builds", S::BUILD_ID, "version" => "1", "processingState" => "VALID", "expired" => false)
    c.build_link = { "type" => "builds", "id" => S::BUILD_ID }
    c.batches[S::EXCLUDED_SUBMISSION_ID] = batch(S::EXCLUDED_SUBMISSION_ID)
    c.items[S::EXCLUDED_SUBMISSION_ID] = [event_item]
    c
  end

  def resource(type, id, attributes)
    { "type" => type, "id" => id, "attributes" => attributes }
  end

  def batch(id, state = "READY_FOR_REVIEW")
    resource("reviewSubmissions", id, "platform" => "IOS", "state" => state)
  end

  def target_item
    resource("reviewSubmissionItems", "target-item", "state" => "READY_FOR_REVIEW").merge(
      "relationships" => S::RELATIONS.to_h { |name| [name, { "data" => name == "appStoreVersion" ? { "type" => "appStoreVersions", "id" => S::VERSION_ID } : nil }] }
    )
  end

  def event_item
    resource("reviewSubmissionItems", "unrelated-event-item", "state" => "READY_FOR_REVIEW").merge(
      "relationships" => { "appStoreVersion" => { "data" => nil }, "appEvent" => { "data" => { "type" => "appEvents", "id" => "event-1" } } }
    )
  end

  def add_target(client, id, state)
    client.batches[id] = batch(id, state)
    client.items[id] = [target_item]
  end
end
