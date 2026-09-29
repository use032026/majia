# frozen_string_literal: true

require "minitest/autorun"
require "time"
require_relative "lib/asc_whats_new"

class FakeASCWhatsNewClient
  attr_reader :calls

  def initialize
    @responses = Hash.new { |hash, key| hash[key] = [] }
    @calls = []
  end

  def enqueue(method, path, response)
    @responses[[method, path]] << response
  end

  def get(path, query = nil)
    take(:get, path, query)
  end

  def paginate(path, query = nil, max_pages: 20)
    _ = max_pages
    take(:paginate, path, query)
  end

  def post(path, payload)
    take(:post, path, payload)
  end

  def patch(path, payload)
    take(:patch, path, payload)
  end

  private

  def take(method, path, argument)
    @calls << [method, path, argument]
    response = @responses.fetch([method, path]).shift
    raise "missing fake response for #{method} #{path}" if response.nil?
    raise response if response.is_a?(Exception)

    response
  end
end

class ASCWhatsNewTest < Minitest::Test
  Sync = MajiaCI::ASCWhatsNew
  APP_ID = "app-1"
  VERSION_ID = "version-101"

  def test_updates_and_verifies_existing_requested_locale
    client = base_client(primary_locale: "en-US")
    localization = version_localization("loc-en", "en-US", "Old notes")
    client.enqueue(:paginate, version_localizations_path, [localization])
    client.enqueue(:patch, "/v1/appStoreVersionLocalizations/loc-en", {})
    client.enqueue(
      :get,
      "/v1/appStoreVersionLocalizations/loc-en",
      { "data" => version_localization("loc-en", "en-US", "fix some bugs。") }
    )

    summary = sync(client)

    assert_equal true, summary["text_metadata_updated"]
    assert_equal "en-US", summary.dig("updated", 0, "applied_locale")
    assert_equal false, summary.dig("updated", 0, "fallback_used")
    assert_equal "fix some bugs。", summary.dig("updated", 0, "whats_new")
    refute client.calls.any? { |method, path, _argument| method == :post && path == "/v1/appStoreVersionLocalizations" }
  end

  def test_uses_existing_primary_locale_without_creating_app_info_localization
    client = base_client(primary_locale: "zh-Hans")
    client.enqueue(:paginate, version_localizations_path, [])
    client.enqueue(:paginate, "/v1/apps/#{APP_ID}/appInfos", [{ "id" => "info-1" }])
    client.enqueue(
      :paginate,
      "/v1/appInfos/info-1/appInfoLocalizations",
      [{ "id" => "info-zh", "attributes" => { "locale" => "zh-Hans" } }]
    )
    created = version_localization("loc-zh", "zh-Hans", nil)
    client.enqueue(:post, "/v1/appStoreVersionLocalizations", { "data" => created })
    client.enqueue(:patch, "/v1/appStoreVersionLocalizations/loc-zh", {})
    client.enqueue(
      :get,
      "/v1/appStoreVersionLocalizations/loc-zh",
      { "data" => version_localization("loc-zh", "zh-Hans", "fix some bugs。") }
    )

    summary = sync(client)

    assert_equal "zh-Hans", summary.dig("updated", 0, "applied_locale")
    assert_equal true, summary.dig("updated", 0, "fallback_used")
    create_call = client.calls.find { |method, path, _argument| method == :post && path == "/v1/appStoreVersionLocalizations" }
    assert_equal "zh-Hans", create_call[2].dig("data", "attributes", "locale")
    refute client.calls.any? { |_method, path, _argument| path == "/v1/appInfoLocalizations" }
  end

  def test_rejects_ambiguous_locale_fallback
    client = base_client(primary_locale: "ja")
    client.enqueue(:paginate, version_localizations_path, [])
    client.enqueue(:paginate, "/v1/apps/#{APP_ID}/appInfos", [{ "id" => "info-1" }])
    client.enqueue(
      :paginate,
      "/v1/appInfos/info-1/appInfoLocalizations",
      [
        { "id" => "info-fr", "attributes" => { "locale" => "fr-FR" } },
        { "id" => "info-de", "attributes" => { "locale" => "de-DE" } }
      ]
    )

    error = assert_raises(MajiaCI::ASCWhatsNewError) { sync(client) }

    assert_includes error.message, "cannot safely map requested locale en-US"
    refute client.calls.any? { |method, _path, _argument| %i[post patch].include?(method) }
  end

  private

  def sync(client)
    Sync.sync(
      client: client,
      bundle_id: "com.lunelle.lite",
      marketing_version: "1.0.1",
      release_notes: { "en-US" => "fix some bugs。" },
      checked_at: Time.utc(2026, 9, 29, 7, 0, 0)
    )
  end

  def base_client(primary_locale:)
    client = FakeASCWhatsNewClient.new
    client.enqueue(
      :paginate,
      "/v1/apps",
      [{ "id" => APP_ID, "attributes" => { "name" => "Jufu", "bundleId" => "com.lunelle.lite" } }]
    )
    client.enqueue(
      :get,
      "/v1/apps/#{APP_ID}",
      {
        "data" => {
          "id" => APP_ID,
          "attributes" => {
            "name" => "Jufu",
            "bundleId" => "com.lunelle.lite",
            "primaryLocale" => primary_locale
          }
        }
      }
    )
    client.enqueue(
      :paginate,
      "/v1/apps/#{APP_ID}/appStoreVersions",
      [
        {
          "id" => VERSION_ID,
          "attributes" => {
            "platform" => "IOS",
            "versionString" => "1.0.1",
            "appVersionState" => "PREPARE_FOR_SUBMISSION",
            "createdDate" => "2026-09-29T07:00:00Z"
          }
        }
      ]
    )
    client
  end

  def version_localizations_path
    "/v1/appStoreVersions/#{VERSION_ID}/appStoreVersionLocalizations"
  end

  def version_localization(id, locale, whats_new)
    attributes = { "locale" => locale }
    attributes["whatsNew"] = whats_new unless whats_new.nil?
    { "id" => id, "attributes" => attributes }
  end
end
