# frozen_string_literal: true

require "minitest/autorun"
require_relative "lib/asc_review_notes"

class ASCReviewNotesTest < Minitest::Test
  Notes = MajiaCI::ASCReviewNotes
  AppID = "6825229832"
  VersionID = "version-1"
  Bundle = "com.fylto.lite"
  Marketing = "1.0.8"
  DetailPath = "/v1/appStoreVersions/#{VersionID}/appStoreReviewDetail"
  VersionsPath = "/v1/apps/#{AppID}/appStoreVersions"
  Canary = "PRIVATE_CONTACT_CANARY"

  class ReadClient
    attr_reader :calls

    def initialize(routes)
      @routes = routes
      @calls = []
    end

    def get(path, query = nil)
      take(:get, path, query)
    end

    def paginate(path, query = nil)
      take(:paginate, path, query)
    end

    private

    def take(method, path, query)
      @calls << [method, path, query]
      raise "unexpected read #{method} #{path}" unless @routes.key?([method, path])

      response = @routes.fetch([method, path])
      raise response if response.is_a?(Exception)

      response
    end
  end

  def test_raw_unicode_notes_hash_lengths_and_all_identity_fields
    raw = "  中文😀e\u0301\r\nsecond line\n "
    result, client = read(notes: raw)
    assert result.fetch("complete")
    assert_empty result.fetch("errors")
    assert_equal 1, result.fetch("schema_version")
    assert_equal "2026-11-21T12:00:00Z", result.fetch("checked_at")
    assert_equal({ "id" => AppID, "bundle_id" => Bundle }, result.fetch("app"))
    assert_equal({ "id" => VersionID, "version_string" => Marketing, "platform" => "IOS" }, result.fetch("version"))
    assert_equal({ "observation" => "present", "notes" => raw, "sha256" => Digest::SHA256.hexdigest(raw),
                   "length" => raw.length, "byte_length" => raw.bytesize }, result.fetch("review_notes"))
    assert_equal [:paginate, :paginate, :get], client.calls.map(&:first)
    assert_equal({ "fields[appStoreReviewDetails]" => "notes" }, client.calls.last.last)
    assert_equal ["/v1/apps", VersionsPath, DetailPath], client.calls.map { |call| call[1] }
    assert_equal Bundle, client.calls[0].last.fetch("filter[bundleId]")
    assert_equal "IOS", client.calls[1].last.fetch("filter[platform]")
    assert_equal Marketing, client.calls[1].last.fetch("filter[versionString]")
  end

  def test_empty_string_is_present_and_hashes_the_raw_empty_string
    result, = read(notes: "")
    assert result.fetch("complete")
    assert_equal "present", result.dig("review_notes", "observation")
    assert_equal "", result.dig("review_notes", "notes")
    assert_equal Digest::SHA256.hexdigest(""), result.dig("review_notes", "sha256")
    assert_equal 0, result.dig("review_notes", "length")
    assert_equal 0, result.dig("review_notes", "byte_length")
  end

  def test_explicit_null_notes_is_distinct_from_absent_detail
    result, = read(notes: nil)
    assert result.fetch("complete")
    assert_equal "null", result.dig("review_notes", "observation")
    assert_nil result.dig("review_notes", "notes")
    assert_nil result.dig("review_notes", "sha256")
    assert_nil result.dig("review_notes", "length")
    result, = read(extra: { [:get, DetailPath] => { "data" => nil } })
    assert result.fetch("complete")
    assert_equal "absent", result.dig("review_notes", "observation")
    assert_nil result.dig("review_notes", "byte_length")
  end

  def test_missing_notes_or_detail_data_is_error_not_empty_or_absent
    [{ "data" => detail({}) }, {}, { "data" => [] }, { "data" => { "type" => "appStoreReviewDetails", "id" => "detail-1" } }].each do |doc|
      result, = read(extra: { [:get, DetailPath] => doc })
      assert_failed(result)
    end
  end

  def test_permission_and_request_errors_are_sanitized_at_each_stage
    [[:paginate, "/v1/apps"], [:paginate, VersionsPath], [:get, DetailPath]].each do |route|
      [MajiaCI::ASCPermissionError, MajiaCI::ASCStatusError].each do |error_class|
        result, = read(extra: { route => error_class.new(Canary) })
        assert_failed(result)
        assert_equal error_class == MajiaCI::ASCPermissionError ? "permission_denied" : "request_failed",
                     result.fetch("errors").first.fetch("code")
        refute_includes JSON.generate(result), Canary
      end
    end
  end

  def test_wrong_app_type_bundle_id_or_multiple_matches_do_not_query_versions
    bad_apps = [
      [app.merge("type" => "builds")], [app.merge("id" => "../unsafe")],
      [app.merge("attributes" => { "bundleId" => "com.other.app" })], [app, app], []
    ]
    bad_apps.each do |apps|
      result, client = read(extra: { [:paginate, "/v1/apps"] => apps })
      assert_failed(result)
      assert_nil result.dig("app", "id")
      assert_equal 1, client.calls.length
    end
  end

  def test_wrong_version_non_ios_foreign_app_or_multiple_matches_do_not_query_detail
    wrong = version.merge("attributes" => { "platform" => "IOS", "versionString" => "1.0.9" })
    mac = version.merge("attributes" => { "platform" => "MAC_OS", "versionString" => Marketing })
    foreign = version.merge("relationships" => { "app" => { "data" => { "type" => "apps", "id" => "1234567890" } } })
    bad_versions = [[wrong], [mac], [foreign], [version, version], [], [version.merge("type" => "builds")], [version.merge("id" => "../unsafe")]]
    bad_versions.each do |versions|
      result, client = read(extra: { [:paginate, VersionsPath] => versions })
      assert_failed(result)
      assert_nil result.dig("version", "id")
      assert_equal [:paginate, :paginate], client.calls.map(&:first)
    end
  end

  def test_explicit_foreign_detail_version_or_wrong_resource_is_not_returned
    foreign = detail({ "notes" => "DO_NOT_RETURN" }).merge("relationships" => {
      "appStoreVersion" => { "data" => { "type" => "appStoreVersions", "id" => "foreign-version" } }
    })
    [foreign, detail({ "notes" => "DO_NOT_RETURN" }).merge("type" => "apps")].each do |bad|
      result, = read(extra: { [:get, DetailPath] => { "data" => bad } })
      assert_failed(result)
      refute_includes JSON.generate(result), "DO_NOT_RETURN"
    end
  end

  def test_extra_contact_demo_and_response_fields_are_not_copied_or_logged
    doc = { "data" => detail({ "notes" => "Review instructions.", "contactEmail" => Canary,
                                "demoAccountPassword" => Canary, "contactPhone" => Canary }),
            "included" => [{ "private" => Canary }], "errors" => [{ "detail" => Canary }] }
    captured = nil
    stdout, stderr = capture_io { captured, = read(extra: { [:get, DetailPath] => doc }) }
    assert_empty stdout
    assert_empty stderr
    assert captured.fetch("complete")
    refute_includes JSON.generate(captured), Canary
    assert_equal "Review instructions.", captured.dig("review_notes", "notes")
  end

  def test_non_string_notes_are_errors_without_serializing_their_contents
    [123, { "secret" => Canary }, [Canary], true].each do |notes|
      result, = read(notes: notes)
      assert_failed(result)
      refute_includes JSON.generate(result), Canary
    end
  end

  def test_links_only_optional_app_relation_uses_scoped_parent_without_an_extra_read
    v = version.merge("relationships" => { "app" => { "links" => { "related" => "https://example.invalid" } } })
    result, client = read(extra: { [:paginate, VersionsPath] => [v] })
    assert result.fetch("complete")
    assert_equal 3, client.calls.length
    refute client.calls.any? { |_method, path, _query| path.include?("relationships") }
  end

  def test_two_component_exact_version_is_not_normalized_to_three_components
    result, client = read(marketing: "1.0", extra: {
      [:paginate, VersionsPath] => [version.merge("attributes" => { "platform" => "IOS", "versionString" => "1.0" })]
    })
    assert result.fetch("complete")
    assert_equal "1.0", result.dig("version", "version_string")
    assert_equal "1.0", client.calls[1].last.fetch("filter[versionString]")
  end

  def test_invalid_input_fails_before_reading_any_resource
    ["", "1.0.8-beta", "1.2.3.4", "01.0", "1" * 33].each do |marketing|
      client = ReadClient.new({})
      assert_raises(MajiaCI::ASCStatusError) { Notes.read(client: client, bundle_id: Bundle, marketing_version: marketing) }
      assert_empty client.calls
    end
    client = ReadClient.new({})
    assert_raises(MajiaCI::ASCStatusError) { Notes.read(client: client, bundle_id: "bad\n#{Canary}", marketing_version: Marketing) }
    assert_empty client.calls
  end

  private

  def assert_failed(result)
    refute result.fetch("complete")
    refute_empty result.fetch("errors")
    assert_equal "unavailable", result.dig("review_notes", "observation")
    assert_nil result.dig("review_notes", "notes")
    assert_nil result.dig("review_notes", "sha256")
  end

  def read(notes: "Existing review notes.", marketing: Marketing, extra: {})
    client = ReadClient.new({ [:paginate, "/v1/apps"] => [app], [:paginate, VersionsPath] => [version],
                              [:get, DetailPath] => { "data" => detail({ "notes" => notes }) } }.merge(extra))
    [Notes.read(client: client, bundle_id: Bundle, marketing_version: marketing, checked_at: Time.utc(2026, 11, 21, 12)), client]
  end

  def app
    { "type" => "apps", "id" => AppID, "attributes" => { "bundleId" => Bundle } }
  end

  def version
    { "type" => "appStoreVersions", "id" => VersionID, "attributes" => { "platform" => "IOS", "versionString" => Marketing } }
  end

  def detail(attributes)
    { "type" => "appStoreReviewDetails", "id" => "detail-1", "attributes" => attributes }
  end
end
