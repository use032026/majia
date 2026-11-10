# frozen_string_literal: true

require "json"
require "minitest/autorun"
require_relative "lib/asc_review_diagnostics"

class ASCReviewDiagnosticsTest < Minitest::Test
  Diagnostic = MajiaCI::ASCReviewDiagnostics
  Bundle = "com.lunelle.lite"
  Version = "1.0.3"
  AppPath = "/v1/apps/app-1"
  VersionPath = "/v1/appStoreVersions/version-1"
  BuildPath = "/v1/builds/build-1"
  AppInfoPath = "/v1/appInfos/info-1"

  class PageClient < MajiaCI::ASCReadClient
    attr_reader :calls

    def initialize(responses)
      @responses = responses
      @calls = []
    end

    def get(path, query = nil)
      @calls << [path, query]
      response = @responses.fetch(path)
      raise response if response.is_a?(Exception)

      response
    end

    def post(*)
      raise "diagnostics must not write"
    end

    alias patch post
    alias post_created post
  end

  def test_exact_diagnostics_output_is_sanitized
    client = test_client
    summary = fetch(client)
    sections = summary.fetch("sections")
    assert_equal true, summary["complete"]
    assert_equal Version, summary.dig("version", "marketing_version")
    assert_equal({
      "contactFirstName" => true,
      "contactLastName" => false,
      "contactPhone" => true,
      "contactEmail" => true
    }, sections.dig("review_contact", "contact_fields_present"))
    assert_equal false, sections.dig("review_contact", "demo_account_required")
    assert_equal true, sections.dig("build_encryption", "uses_non_exempt_encryption")
    assert_equal true, sections.dig("build_encryption", "declaration_present")
    assert_equal "APPROVED", sections.dig("build_encryption", "declaration_state")
    info = sections.dig("age_rating", "app_infos").first
    assert_equal "FOUR_PLUS", info["app_store_age_rating"]
    assert_equal true, info.dig("core_answers_present", "ageAssurance")
    assert_equal false, info.dig("core_answers_present", "userGeneratedContent")
    assert_equal({
      "status" => "observed",
      "target_submissions" => [
        { "state" => "READY_FOR_REVIEW", "version_linked_directly" => true, "item_states" => [] },
        { "state" => "READY_FOR_REVIEW", "version_linked_directly" => false, "item_states" => ["READY_FOR_REVIEW"] },
        { "state" => "READY_FOR_REVIEW", "version_linked_directly" => true, "item_states" => ["READY_FOR_REVIEW"] }
      ],
      "empty_ready_drafts" => 1,
      "ready_drafts_with_unknown_version_link" => 1
    }, sections.fetch("review_drafts"))
    assert_includes client.calls, ["/draft-page-two", nil]
    assert_includes client.calls, ["/item-page-two", nil]
    assert_equal "appStoreVersionForReview", client.calls.assoc("#{AppPath}/reviewSubmissions").last["include"]
    assert_equal "appStoreVersion", client.calls.assoc("/v1/reviewSubmissions/target-1/items").last["include"]
    contact_fields = client.calls.assoc("#{VersionPath}/appStoreReviewDetail").last.fetch("fields[appStoreReviewDetails]").split(",")
    assert_equal %w[contactFirstName contactLastName contactPhone contactEmail demoAccountRequired], contact_fields
    assert_equal Version, client.calls.assoc("#{AppPath}/appStoreVersions").last["filter[versionString]"]
    refute_includes JSON.generate(summary), "Private"
  end

  def test_section_errors_are_reported_without_private_details
    client = test_client(
      "#{VersionPath}/appStoreReviewDetail" => MajiaCI::ASCStatusError.new("Private server response"),
      "/item-page-two" => MajiaCI::ASCStatusError.new("Private server response")
    )
    summary = fetch(client)
    assert_equal false, summary["complete"]
    assert_equal({ "status" => "unavailable" }, summary.dig("sections", "review_contact"))
    assert_equal({ "status" => "unavailable" }, summary.dig("sections", "review_drafts"))
    assert_equal "observed", summary.dig("sections", "build_encryption", "status")
    refute_includes JSON.generate(summary), "Private"
  end

  def test_explicitly_absent_relationships_are_not_query_errors
    summary = fetch(test_client(
      "#{VersionPath}/relationships/appStoreReviewDetail" => data(nil),
      "#{BuildPath}/relationships/appEncryptionDeclaration" => data(nil),
      "#{AppInfoPath}/relationships/ageRatingDeclaration" => data(nil)
    ))
    assert_equal true, summary["complete"]
    assert_equal "absent", summary.dig("sections", "review_contact", "status")
    assert_equal false, summary.dig("sections", "build_encryption", "declaration_present")
    assert_nil summary.dig("sections", "build_encryption", "declaration_state")
    assert_equal false, summary.dig("sections", "age_rating", "app_infos", 0, "declaration_present")
  end

  def test_blank_or_nonmatching_version_cannot_query_diagnostic_endpoints
    client = test_client
    assert_raises(MajiaCI::ASCStatusError) do
      Diagnostic.read(client: client, bundle_id: Bundle, marketing_version: "")
    end
    assert_empty client.calls
    assert_raises(MajiaCI::ASCStatusError) do
      Diagnostic.read(client: client, bundle_id: Bundle, marketing_version: "1.0.2")
    end
    assert_equal ["/v1/apps", "#{AppPath}/appStoreVersions"], client.calls.map(&:first)
  end

  private

  def fetch(client)
    Diagnostic.read(client: client, bundle_id: Bundle, marketing_version: Version)
  end

  def test_client(overrides = {})
    PageClient.new({
      "/v1/apps" => data([resource("app-1", "bundleId" => Bundle)]),
      "#{AppPath}/appStoreVersions" => data([resource("version-1", "versionString" => Version, "platform" => "IOS")]),
      "#{VersionPath}/relationships/appStoreReviewDetail" => data({ "id" => "contact-1" }),
      "#{VersionPath}/appStoreReviewDetail" => data(resource("contact-1", {
        "contactFirstName" => "Private Contact",
        "contactLastName" => "  ",
        "contactPhone" => "Private Phone",
        "contactEmail" => "Private Email",
        "demoAccountRequired" => false,
        "demoAccountPassword" => "Private Password"
      })),
      "#{VersionPath}/relationships/build" => data({ "id" => "build-1" }),
      BuildPath => data(resource("build-1", "usesNonExemptEncryption" => true)),
      "#{BuildPath}/relationships/appEncryptionDeclaration" => data({ "id" => "encryption-1" }),
      "/v1/appEncryptionDeclarations/encryption-1" => data(resource("encryption-1", "appEncryptionDeclarationState" => "APPROVED")),
      "#{AppPath}/appInfos" => data([resource("info-1", "state" => "PREPARE_FOR_SUBMISSION", "appStoreAgeRating" => "FOUR_PLUS")]),
      "#{AppInfoPath}/relationships/ageRatingDeclaration" => data({ "id" => "rating-1" }),
      "#{AppInfoPath}/ageRatingDeclaration" => data(resource("rating-1", "ageAssurance" => false, "userGeneratedContent" => nil)),
      "#{AppPath}/reviewSubmissions" => data([
        submission("empty-1", nil),
        submission("direct-1", "version-1"),
        submission("other-1", "other-version"),
        resource("unknown-1", "state" => "READY_FOR_REVIEW")
      ], "/draft-page-two"),
      "/draft-page-two" => data([
        submission("target-1", nil),
        submission("both-1", "version-1")
      ]),
      "/v1/reviewSubmissions/empty-1/items" => data([]),
      "/v1/reviewSubmissions/direct-1/items" => data([]),
      "/v1/reviewSubmissions/other-1/items" => data([]),
      "/v1/reviewSubmissions/unknown-1/items" => data([]),
      "/v1/reviewSubmissions/target-1/items" => data([item("other-version")], "/item-page-two"),
      "/v1/reviewSubmissions/both-1/items" => data([item("version-1")]),
      "/item-page-two" => data([item("version-1")])
    }.merge(overrides))
  end

  def resource(id, attributes)
    { "id" => id, "attributes" => attributes }
  end

  def data(value, next_page = nil)
    { "data" => value, "links" => { "next" => next_page } }
  end

  def item(version_id)
    resource("item-1", "state" => "READY_FOR_REVIEW").merge(
      "relationships" => { "appStoreVersion" => { "data" => { "id" => version_id } } }
    )
  end

  def submission(id, version_id)
    link = { "type" => "appStoreVersions", "id" => version_id } if version_id
    resource(id, "state" => "READY_FOR_REVIEW").merge(
      "relationships" => { "appStoreVersionForReview" => { "data" => link } }
    )
  end
end
