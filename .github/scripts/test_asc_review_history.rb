# frozen_string_literal: true

require "minitest/autorun"
require_relative "lib/asc_review_history"

class ASCReviewHistoryTest < Minitest::Test
  History = MajiaCI::ASCReviewHistory
  AppID = "6825229832"
  Bundle = "com.fylto.lite"
  AppPath = "/v1/apps/#{AppID}"
  VersionsPath = "#{AppPath}/appStoreVersions"
  SubmissionsPath = "#{AppPath}/reviewSubmissions"
  CheckedAt = Time.utc(2026, 11, 21, 1, 0)
  Secret = "SECRET_CANARY_DO_NOT_SHOW"

  # The real history reader performs each GET and follows next links itself.
  # This transport deliberately exposes no paginate, POST, PATCH, signing or account key.
  class GetTransport
    attr_reader :calls

    def initialize(routes)
      @routes = routes
      @calls = []
    end

    def get(path, query = nil)
      @calls << ["GET", path, query]
      raise "unexpected GET path: #{path}" unless @routes.key?(path)

      response = @routes.fetch(path)
      response = response.shift if response.is_a?(Array)
      raise response if response.is_a?(Exception)

      response
    end
  end

  def test_nine_distinct_verified_versions_stop_automatic_submissions
    result, client = read(versions: nine_versions)
    assert_equal 9, result.fetch("confirmed_distinct_submitted_lower_bound")
    assert_equal({ "label" => "可使用", "stop_auto_submission" => true }, result.fetch("decision"))
    assert_equal({ "id" => AppID, "bundle_id" => Bundle }, result.fetch("app"))
    assert_equal "IOS", result.fetch("platform")
    assert_equal CheckedAt.iso8601, result.fetch("checked_at")
    assert result.fetch("api_scan_complete")
    refute result.fetch("history_complete")
    assert_empty result.fetch("errors")
    assert_empty result.fetch("unknowns")
    assert client.calls.all? { |method, _path, _query| method == "GET" }
    refute client.calls.any? { |_method, path, _query| path.match?(/build|upload|relationships\/app/) }
    assert_equal "IOS", client.calls.find { |_method, path, _query| path == VersionsPath }.last.fetch("filter[platform]")
    assert_equal "IOS", client.calls.find { |_method, path, _query| path == SubmissionsPath }.last.fetch("filter[platform]")
  end

  def test_eight_fully_scanned_records_are_still_not_complete_lifetime_history
    result, = read(versions: nine_versions.take(8))
    assert_equal 8, result.fetch("confirmed_distinct_submitted_lower_bound")
    assert result.fetch("api_scan_complete")
    refute result.fetch("history_complete")
    assert_equal({ "label" => "待核实", "stop_auto_submission" => nil }, result.fetch("decision"))
  end

  def test_version_and_submission_and_item_pages_are_all_followed
    v_next = absolute(VersionsPath, "v2")
    s_next = absolute(SubmissionsPath, "s2")
    i_path = "/v1/reviewSubmissions/batch-1/items"
    i_next = absolute(i_path, "i2")
    v = version("version-1", "1.0.0", "PREPARE_FOR_SUBMISSION")
    routes = {
      VersionsPath => document([], next_link: v_next), v_next => document([v]),
      SubmissionsPath => document([], next_link: s_next),
      s_next => document([submission("batch-1", "COMPLETE")]),
      i_path => document([other_item], next_link: i_next),
      i_next => document([item("item-1", "version-1", "APPROVED")])
    }
    result, client = read(extra: routes)
    assert_equal 1, result.fetch("confirmed_distinct_submitted_lower_bound")
    assert result.fetch("api_scan_complete")
    assert_equal [v_next, s_next, i_next], client.calls.select { |_m, path, _q| path.start_with?("https:") }.map { |c| c[1] }
    assert_equal "appStoreVersion", client.calls.find { |_m, path, _q| path == i_path }.last.fetch("include")
    refute_includes client.calls.find { |_m, path, _q| path == VersionsPath }.last.fetch("fields[appStoreVersions]").split(","), "appStoreState"
    assert client.calls.select { |_m, path, _q| path.start_with?("https:") }.all? { |_m, _p, q| q.nil? }
    evidence = result.fetch("distinct_versions").first.fetch("evidence").first
    assert_equal "batch-1", evidence.fetch("submission_id")
    assert_equal "item-1", evidence.fetch("item_id")
    assert_equal "2026-11-20T12:00:00Z", evidence.fetch("submitted_date")
  end

  def test_marketing_version_deduplicates_version_resources_and_retried_batches
    versions = [version("version-1", "1.0.0"), version("version-2", "1.0.0")]
    submissions = [submission("batch-1", "COMPLETE"), submission("batch-2", "COMPLETE")]
    extra = {
      "/v1/reviewSubmissions/batch-1/items" => document([item("item-1", "version-1", "APPROVED")]),
      "/v1/reviewSubmissions/batch-2/items" => document([item("item-2", "version-1", "APPROVED")])
    }
    result, = read(versions: versions, submissions: submissions, extra: extra)
    assert_equal 1, result.fetch("confirmed_distinct_submitted_lower_bound")
    entry = result.fetch("distinct_versions").first
    assert_equal %w[version-1 version-2], entry.fetch("version_ids")
    assert_equal 3, entry.fetch("evidence").length # one identical version-state proof, two real batches
  end

  def test_drafts_uploads_and_empty_review_drafts_do_not_count
    versions = [version("draft-1", "1.0.0", "PREPARE_FOR_SUBMISSION"), version("draft-2", "1.0.1", "READY_FOR_REVIEW")]
    submissions = [submission("empty-draft", "READY_FOR_REVIEW", date: nil)]
    result, client = read(versions: versions, submissions: submissions, extra: {
      "/v1/reviewSubmissions/empty-draft/items" => document([])
    })
    assert_equal 0, result.fetch("confirmed_distinct_submitted_lower_bound")
    assert result.fetch("api_scan_complete")
    refute client.calls.any? { |_m, path, _q| path.include?("build") || path.include?("upload") }
  end

  def test_linked_draft_without_submitted_date_does_not_count
    result, = read(versions: [version("version-1", "1.0.0", "READY_FOR_REVIEW")],
                  submissions: [submission("draft-1", "READY_FOR_REVIEW", date: nil, direct: "version-1")],
                  extra: { "/v1/reviewSubmissions/draft-1/items" => document([item("item-1", "version-1", "READY_FOR_REVIEW")]) })
    assert_equal 0, result.fetch("confirmed_distinct_submitted_lower_bound")
    assert result.fetch("api_scan_complete")
  end

  def test_removed_item_or_other_asset_does_not_prove_the_app_version_was_submitted
    result, = read(versions: [version("version-1", "1.0.0", "PREPARE_FOR_SUBMISSION")],
                  submissions: [submission("batch-1", "COMPLETE")],
                  extra: { "/v1/reviewSubmissions/batch-1/items" => document([item("removed-1", "version-1", "REMOVED"), other_item]) })
    assert_equal 0, result.fetch("confirmed_distinct_submitted_lower_bound")
    assert_empty result.fetch("distinct_versions")
  end

  def test_queued_item_requires_accepted_date_and_matching_direct_app_version
    result, = read(versions: [version("version-1", "1.0.0", "PREPARE_FOR_SUBMISSION")],
                  submissions: [submission("batch-1", "WAITING_FOR_REVIEW", direct: "version-1")],
                  extra: { "/v1/reviewSubmissions/batch-1/items" => document([item("item-1", "version-1", "READY_FOR_REVIEW")]) })
    assert_equal 1, result.fetch("confirmed_distinct_submitted_lower_bound")
    assert_equal "review_submission_item", result.fetch("distinct_versions").first.fetch("evidence").first.fetch("kind")
  end

  def test_completed_batch_with_only_ready_item_does_not_prove_formal_app_version_submission
    result, = read(versions: [version("version-1", "1.0.0", "PREPARE_FOR_SUBMISSION")],
                  submissions: [submission("batch-1", "COMPLETE", direct: "version-1")],
                  extra: { "/v1/reviewSubmissions/batch-1/items" => document([item("item-1", "version-1", "READY_FOR_REVIEW")]) })
    assert_equal 0, result.fetch("confirmed_distinct_submitted_lower_bound")
    assert_includes result.fetch("unknowns").map { |e| e["code"] }, "unproven_item_submission"
  end

  def test_rejected_and_withdrawn_versions_count_once_without_treating_removed_item_as_proof
    result, = read(versions: [version("version-1", "1.0.0", "REJECTED"), version("version-2", "1.0.0", "DEVELOPER_REJECTED")])
    assert_equal 1, result.fetch("confirmed_distinct_submitted_lower_bound")
    assert_equal %w[REJECTED DEVELOPER_REJECTED], result.fetch("distinct_versions").first.fetch("app_version_states")
  end

  def test_only_app_store_version_invalid_binary_is_confirmed_not_export_compliance
    result, = read(versions: [version("version-1", "1.0.0", "INVALID_BINARY"), version("version-2", "1.0.1", "WAITING_FOR_EXPORT_COMPLIANCE")])
    assert_equal 1, result.fetch("confirmed_distinct_submitted_lower_bound")
    assert_equal "INVALID_BINARY", result.fetch("distinct_versions").first.fetch("app_version_states").first
    refute result.fetch("api_scan_complete")
    assert_equal 1, result.fetch("unknowns").length
  end

  def test_foreign_app_non_ios_and_wrong_resource_types_cannot_enter_version_map
    foreign = version("foreign-1", "1.0.0")
    foreign["relationships"] = { "app" => { "data" => { "type" => "apps", "id" => "1234567890" } } }
    mac = version("mac-1", "1.0.1")
    mac["attributes"]["platform"] = "MAC_OS"
    wrong = version("wrong-1", "1.0.2").merge("type" => "builds")
    result, = read(versions: [foreign, mac, wrong])
    assert_equal 0, result.fetch("confirmed_distinct_submitted_lower_bound")
    refute result.fetch("api_scan_complete")
    assert_equal 3, result.fetch("unknowns").length
  end

  def test_out_of_scope_item_and_missing_relationship_are_explicit_gaps
    missing = item("missing-1", "version-1", "APPROVED")
    missing.delete("relationships")
    result, = read(versions: [version("version-1", "1.0.0", "PREPARE_FOR_SUBMISSION")],
                  submissions: [submission("batch-1", "COMPLETE")], extra: {
                    "/v1/reviewSubmissions/batch-1/items" => document([item("foreign-1", "foreign-version", "APPROVED"), missing])
                  })
    assert_equal 0, result.fetch("confirmed_distinct_submitted_lower_bound")
    assert_equal %w[item_version_out_of_scope missing_item_relationships], result.fetch("unknowns").map { |e| e["code"] }
    refute result.fetch("api_scan_complete")
  end

  def test_invalid_app_identity_stops_before_app_scoped_requests
    [app.merge("type" => "builds"), app.merge("id" => "../unsafe"), app.merge("attributes" => { "bundleId" => "com.other.app" })].each do |bad|
      result, client = read(extra: { "/v1/apps" => document([bad]) })
      assert_nil result.dig("app", "id")
      assert_equal 0, result.fetch("confirmed_distinct_submitted_lower_bound")
      assert_equal ["/v1/apps"], client.calls.map { |call| call[1] }
      refute result.fetch("api_scan_complete")
    end
  end

  def test_multiple_app_matches_are_not_silently_selected
    result, client = read(extra: { "/v1/apps" => document([app, app.merge("id" => "1234567890")]) })
    assert_nil result.dig("app", "id")
    assert_equal 1, client.calls.length
  end

  def test_second_page_permission_failure_retains_verified_first_page_lower_bound
    next_link = absolute(VersionsPath, "page2")
    result, = read(extra: {
      VersionsPath => document(nine_versions, next_link: next_link),
      next_link => MajiaCI::ASCPermissionError.new("FORBIDDEN #{Secret}")
    })
    assert_equal 9, result.fetch("confirmed_distinct_submitted_lower_bound")
    refute result.fetch("api_scan_complete")
    assert_equal true, result.dig("decision", "stop_auto_submission")
    assert_equal [{ "code" => "permission_denied", "scope" => "versions" }], result.fetch("errors")
    refute_includes JSON.generate(result), Secret
  end

  def test_item_page_failure_retains_independent_proven_version_and_flags_partial
    result, = read(versions: [version("version-1", "1.0.0")], submissions: [submission("batch-1", "COMPLETE")], extra: {
      "/v1/reviewSubmissions/batch-1/items" => MajiaCI::ASCStatusError.new("private response #{Secret}")
    })
    assert_equal 1, result.fetch("confirmed_distinct_submitted_lower_bound")
    refute result.fetch("api_scan_complete")
    assert_equal "request_failed", result.fetch("errors").first.fetch("code")
    refute_includes JSON.generate(result), Secret
  end

  def test_unsafe_next_links_are_never_requested_and_do_not_erase_confirmed_rows
    bad_links = [
      "https://evil.example#{VersionsPath}", "http://api.appstoreconnect.apple.com#{VersionsPath}",
      "https://api.appstoreconnect.apple.com:444#{VersionsPath}",
      "https://user@api.appstoreconnect.apple.com#{VersionsPath}",
      "https://api.appstoreconnect.apple.com/v1/apps/1234567890/appStoreVersions",
      "#{absolute(VersionsPath, 'a')}#fragment", "//api.appstoreconnect.apple.com#{VersionsPath}",
      { "href" => "https://evil.example" }
    ]
    bad_links.each do |link|
      result, client = read(extra: { VersionsPath => document([version("version-1", "1.0.0")], next_link: link) })
      assert_equal 1, result.fetch("confirmed_distinct_submitted_lower_bound")
      assert_equal "unsafe_pagination_link", result.fetch("errors").first.fetch("code")
      refute client.calls.any? { |_m, path, _q| path == link }
    end
  end

  def test_next_page_cycle_stops_without_blind_retry
    link = absolute(VersionsPath, "cycle")
    result, client = read(extra: {
      VersionsPath => document([version("version-1", "1.0.0")], next_link: link),
      link => document([], next_link: link)
    })
    assert_equal 1, result.fetch("confirmed_distinct_submitted_lower_bound")
    assert_equal "pagination_loop", result.fetch("errors").first.fetch("code")
    assert_equal 1, client.calls.count { |_m, path, _q| path == link }
  end

  def test_page_limit_is_explicit_and_preserves_lower_bound
    routes = {}
    20.times do |index|
      path = index.zero? ? VersionsPath : absolute(VersionsPath, index.to_s)
      routes[path] = document([version("v-#{index}", "1.0.#{index}")], next_link: absolute(VersionsPath, (index + 1).to_s))
    end
    result, client = read(extra: routes)
    assert_equal 20, result.fetch("confirmed_distinct_submitted_lower_bound")
    assert_equal 20, client.calls.count { |_m, path, _q| path.include?("appStoreVersions") }
    assert_equal "pagination_limit", result.fetch("errors").first.fetch("code")
    refute result.fetch("api_scan_complete")
  end

  def test_malformed_response_and_relationship_are_gaps_not_observed_zero_history
    bad = item("bad-1", "version-1", "APPROVED")
    bad["relationships"]["appStoreVersion"] = { "links" => { "related" => "https://evil.example" } }
    result, = read(versions: [version("version-1", "1.0.0", "PREPARE_FOR_SUBMISSION")],
                  submissions: [submission("batch-1", "COMPLETE")], extra: {
                    "/v1/reviewSubmissions/batch-1/items" => document([bad])
                  })
    assert_equal 0, result.fetch("confirmed_distinct_submitted_lower_bound")
    assert_equal "unresolved_item_version_relationship", result.fetch("unknowns").first.fetch("code")
    refute result.fetch("api_scan_complete")
    result, = read(extra: { VersionsPath => { "data" => nil } })
    assert_equal "invalid_list_response", result.fetch("errors").first.fetch("code")
    refute result.fetch("api_scan_complete")
  end

  def test_unvalidated_remote_text_is_not_exposed_in_history_evidence
    malicious = version("version-1", "1.0.0")
    malicious["id"] = "#{Secret}<script>"
    malicious["attributes"]["appVersionState"] = Secret
    bad_name = version("version-2", "1.0.1")
    bad_name["attributes"]["versionString"] = "1.0.1\n#{Secret}"
    result, = read(versions: [malicious, bad_name])
    assert_equal 0, result.fetch("confirmed_distinct_submitted_lower_bound")
    refute_includes JSON.generate(result), Secret
    refute_includes JSON.generate(result), "<script>"
  end

  def test_invalid_or_missing_submission_date_cannot_prove_a_draft_version
    [nil, "invalid #{Secret}", "2026-02-30T12:00:00Z"].each do |date|
      result, = read(versions: [version("version-1", "1.0.0", "PREPARE_FOR_SUBMISSION")],
                    submissions: [submission("batch-1", "COMPLETE", date: date)], extra: {
                      "/v1/reviewSubmissions/batch-1/items" => document([item("item-1", "version-1", "APPROVED")])
                    })
      assert_equal 0, result.fetch("confirmed_distinct_submitted_lower_bound")
      refute_includes JSON.generate(result), Secret
    end
  end

  def test_historical_two_component_marketing_version_is_preserved_without_guessing_alias
    result, = read(versions: [version("first-release", "1.0", "READY_FOR_DISTRIBUTION")])
    assert_equal 1, result.fetch("confirmed_distinct_submitted_lower_bound")
    assert_equal ["1.0"], result.fetch("distinct_versions").map { |row| row.fetch("marketing_version") }
    refute_includes JSON.generate(result), "1.0.0"
  end

  def test_ambiguous_legacy_states_do_not_inflate_the_lower_bound
    states = %w[PREORDER_READY_FOR_SALE REPLACED_WITH_NEW_VERSION REMOVED_FROM_SALE DEVELOPER_REMOVED_FROM_SALE]
    result, = read(versions: states.each_with_index.map { |state, index| version("version-#{index}", "1.0.#{index}", state) })
    assert_equal 0, result.fetch("confirmed_distinct_submitted_lower_bound")
    assert_equal 4, result.fetch("unknowns").length
    refute result.fetch("api_scan_complete")
  end

  def test_malformed_app_relationship_is_a_gap_without_an_uncaught_type_error
    bad = version("version-1", "1.0.0")
    bad["relationships"] = { "app" => "invalid" }
    result, = read(versions: [bad])
    assert_equal 0, result.fetch("confirmed_distinct_submitted_lower_bound")
    assert_equal "version_scope_unverified", result.fetch("unknowns").first.fetch("code")
  end

  def test_scoped_listings_allow_optional_links_only_app_relationships_without_following_them
    v = version("version-1", "1.0.0")
    batch = submission("batch-1", "COMPLETE")
    [v, batch].each do |resource|
      resource["relationships"] = { "app" => { "links" => {
        "self" => "https://api.appstoreconnect.apple.com/v1/unused/relationships/app",
        "related" => "https://api.appstoreconnect.apple.com/v1/apps/#{AppID}"
      } } }
    end
    result, client = read(versions: [v], submissions: [batch], extra: {
      "/v1/reviewSubmissions/batch-1/items" => document([item("item-1", "version-1", "APPROVED")])
    })
    assert_equal 1, result.fetch("confirmed_distinct_submitted_lower_bound")
    assert result.fetch("api_scan_complete")
    assert_empty result.fetch("unknowns")
    refute client.calls.any? { |_m, path, _q| path.include?("relationships/app") }
    query = client.calls.find { |_m, path, _q| path == VersionsPath }.last
    refute_includes query.fetch("fields[appStoreVersions]").split(","), "app"
    query = client.calls.find { |_m, path, _q| path == SubmissionsPath }.last
    refute_includes query.fetch("fields[reviewSubmissions]").split(","), "app"
  end

  def test_explicit_foreign_submission_app_is_rejected_before_items_are_queried
    batch = submission("batch-1", "COMPLETE")
    batch["relationships"] = { "app" => { "data" => { "type" => "apps", "id" => "1234567890" } } }
    result, client = read(versions: [version("version-1", "1.0.0", "PREPARE_FOR_SUBMISSION")], submissions: [batch])
    assert_equal 0, result.fetch("confirmed_distinct_submitted_lower_bound")
    assert_equal "submission_scope_unverified", result.fetch("unknowns").first.fetch("code")
    refute result.fetch("api_scan_complete")
    refute client.calls.any? { |_m, path, _q| path.include?("/items") }
  end

  def test_invalid_bundle_is_rejected_before_any_get
    client = GetTransport.new({})
    assert_raises(MajiaCI::ASCStatusError) { History.read(client: client, bundle_id: "bad\n#{Secret}") }
    assert_empty client.calls
  end

  private

  def read(versions: [], submissions: [], extra: {})
    routes = { "/v1/apps" => document([app]), VersionsPath => document(versions), SubmissionsPath => document(submissions) }.merge(extra)
    client = GetTransport.new(routes)
    [History.read(client: client, bundle_id: Bundle, checked_at: CheckedAt), client]
  end

  def app
    { "type" => "apps", "id" => AppID, "attributes" => { "bundleId" => Bundle } }
  end

  def version(id, marketing, state = "WAITING_FOR_REVIEW")
    { "type" => "appStoreVersions", "id" => id,
      "attributes" => { "platform" => "IOS", "versionString" => marketing, "appVersionState" => state } }
  end

  def nine_versions
    9.times.map { |index| version("version-#{index}", "1.0.#{index}") }
  end

  def submission(id, state, date: "2026-11-20T12:00:00Z", direct: nil)
    resource = { "type" => "reviewSubmissions", "id" => id,
                 "attributes" => { "platform" => "IOS", "state" => state, "submittedDate" => date } }
    if direct
      resource["relationships"] = { "appStoreVersionForReview" => { "data" => { "type" => "appStoreVersions", "id" => direct } } }
    end
    resource
  end

  def item(id, version_id, state)
    { "type" => "reviewSubmissionItems", "id" => id, "attributes" => { "state" => state },
      "relationships" => { "appStoreVersion" => { "data" => { "type" => "appStoreVersions", "id" => version_id } } } }
  end

  def other_item
    { "type" => "reviewSubmissionItems", "id" => "event-1", "attributes" => { "state" => "APPROVED" },
      "relationships" => { "appStoreVersion" => { "data" => nil }, "appEvent" => { "data" => { "type" => "appEvents", "id" => "event-1" } } } }
  end

  def document(rows, next_link: nil)
    { "data" => rows, "links" => { "next" => next_link } }
  end

  def absolute(path, cursor)
    "https://api.appstoreconnect.apple.com#{path}?cursor=#{cursor}"
  end
end
