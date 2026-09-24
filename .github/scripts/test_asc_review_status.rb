# frozen_string_literal: true

require "json"
require "minitest/autorun"
require "openssl"
require "time"
require_relative "lib/asc_review_status"

class FakeASCReadClient
  attr_reader :calls

  def initialize
    @responses = {}
    @calls = []
  end

  def enqueue(method, path, response)
    @responses[[method, path]] = response
  end

  def get(path, query = nil)
    take(:get, path, query)
  end

  def paginate(path, query = nil, max_pages: 20)
    _ = max_pages
    take(:paginate, path, query)
  end

  private

  def take(method, path, query)
    @calls << [method, path, query]
    @responses.fetch([method, path])
  end
end

class ASCReviewStatusTest < Minitest::Test
  Status = MajiaCI::ASCReviewStatus
  APP_ID = "1234567890"
  VERSION_ID = "version-100"

  def test_jwt_is_es256_signed_and_uses_the_asc_audience
    key = OpenSSL::PKey::EC.generate("prime256v1")
    now = Time.utc(2026, 9, 24, 1, 2, 3)
    token = Status.jwt(
      key: key,
      key_id: "ABCDEF1234",
      issuer_id: "12345678-1234-1234-1234-1234567890ab",
      now: now
    )
    encoded_header, encoded_payload, encoded_signature = token.split(".")
    header = JSON.parse(base64url_decode(encoded_header))
    payload = JSON.parse(base64url_decode(encoded_payload))
    signature = base64url_decode(encoded_signature)
    r = OpenSSL::BN.new(signature.byteslice(0, 32), 2)
    s = OpenSSL::BN.new(signature.byteslice(32, 32), 2)
    der = OpenSSL::ASN1::Sequence([
      OpenSSL::ASN1::Integer(r),
      OpenSSL::ASN1::Integer(s)
    ]).to_der

    assert_equal({ "alg" => "ES256", "kid" => "ABCDEF1234", "typ" => "JWT" }, header)
    assert_equal "appstoreconnect-v1", payload["aud"]
    assert_equal now.to_i + 600, payload["exp"]
    assert key.dsa_verify_asn1(
      OpenSSL::Digest::SHA256.digest("#{encoded_header}.#{encoded_payload}"),
      der
    )
  end

  def test_build_status_links_the_version_build_and_active_review_submission
    client = base_client
    client.enqueue(
      :get,
      "/v1/appStoreVersions/#{VERSION_ID}/relationships/build",
      { "data" => { "type" => "builds", "id" => "build-42" } }
    )
    client.enqueue(
      :get,
      "/v1/builds/build-42",
      {
        "data" => {
          "type" => "builds",
          "id" => "build-42",
          "attributes" => {
            "version" => "42",
            "processingState" => "VALID",
            "uploadedDate" => "2026-09-23T01:00:00Z",
            "expired" => false
          }
        }
      }
    )
    client.enqueue(
      :paginate,
      "/v1/apps/#{APP_ID}/reviewSubmissions",
      [
        submission("old-submission", "COMPLETE", "2026-09-22T01:00:00Z"),
        submission("active-submission", "IN_REVIEW", "2026-09-24T01:00:00Z")
      ]
    )
    client.enqueue(
      :paginate,
      "/v1/reviewSubmissions/old-submission/items",
      [review_item("old-item", VERSION_ID, "ACCEPTED")]
    )
    client.enqueue(
      :paginate,
      "/v1/reviewSubmissions/active-submission/items",
      [review_item("active-item", VERSION_ID, "IN_REVIEW")]
    )

    summary = Status.build_status(
      client: client,
      bundle_id: "com.example.app",
      marketing_version: "1.0.0",
      checked_at: Time.utc(2026, 9, 24, 2, 0, 0)
    )

    assert_equal "IN_REVIEW", summary.dig("version", "app_version_state")
    assert_equal "IN_REVIEW", summary.dig("version", "review_stage")
    assert_equal "42", summary.dig("build", "version")
    assert_equal "VALID", summary.dig("build", "processing_state")
    assert_equal "active-submission", summary.dig("review_submission", "id")
    assert_equal "IN_REVIEW", summary.dig("review_submission", "item_state")
    assert_nil summary["review_submission_query_error"]
  end

  def test_latest_version_and_missing_optional_relations_are_reported_without_mutation
    client = FakeASCReadClient.new
    client.enqueue(:paginate, "/v1/apps", [app])
    client.enqueue(
      :paginate,
      "/v1/apps/#{APP_ID}/appStoreVersions",
      [version("1.2.0", "READY_FOR_DISTRIBUTION", "2026-09-20T00:00:00Z", "old-version"),
       version("1.3.0", "WAITING_FOR_REVIEW", "2026-09-24T00:00:00Z", VERSION_ID)]
    )
    client.enqueue(:get, "/v1/appStoreVersions/#{VERSION_ID}/relationships/build", { "data" => nil })
    client.enqueue(:paginate, "/v1/apps/#{APP_ID}/reviewSubmissions", [])

    summary = Status.build_status(client: client, bundle_id: "com.example.app")

    assert_equal "1.3.0", summary.dig("version", "version_string")
    assert_equal "QUEUED_FOR_REVIEW", summary.dig("version", "review_stage")
    assert_nil summary["build"]
    assert_nil summary["review_submission"]
    assert client.calls.all? { |method, _path, _query| %i[get paginate].include?(method) }
  end

  def test_review_submission_permission_error_keeps_the_version_snapshot
    client = base_client
    client.enqueue(:get, "/v1/appStoreVersions/#{VERSION_ID}/relationships/build", { "data" => nil })
    client.enqueue(
      :paginate,
      "/v1/apps/#{APP_ID}/reviewSubmissions",
      MajiaCI::ASCStatusError.new("ASC request failed: FORBIDDEN")
    )
    def client.paginate(path, query = nil, max_pages: 20)
      response = super
      raise response if response.is_a?(Exception)

      response
    end

    summary = Status.build_status(
      client: client,
      bundle_id: "com.example.app",
      marketing_version: "1.0.0"
    )

    assert_equal "IN_REVIEW", summary.dig("version", "app_version_state")
    assert_equal "ASC request failed: FORBIDDEN", summary["review_submission_query_error"]
  end

  def test_workflow_uses_existing_environment_credentials_without_signing_material
    text = File.read(File.expand_path("../workflows/asc-review-status.yml", __dir__), encoding: "UTF-8")

    %w[tripcost-production hearthio-production sdpacket-production photo-production].each do |environment|
      assert_includes text, "- #{environment}"
    end
    assert_includes text, "environment: ${{ inputs.app_environment }}"
    assert_includes text, "ASC_API_KEY_P8: ${{ secrets.ASC_API_KEY_P8 }}"
    refute_includes text, "IOS_DISTRIBUTION_P12_BASE64"
    refute_includes text, "IOS_APPSTORE_PROFILE_BASE64"
    refute_includes text, "upload_to_asc"
    refute_includes text, "submit_to_review"
  end

  private

  def base64url_decode(value)
    Base64.urlsafe_decode64(value.ljust((value.length + 3) / 4 * 4, "="))
  end

  def base_client
    client = FakeASCReadClient.new
    client.enqueue(:paginate, "/v1/apps", [app])
    client.enqueue(
      :paginate,
      "/v1/apps/#{APP_ID}/appStoreVersions",
      [version("1.0.0", "IN_REVIEW", "2026-09-24T00:00:00Z", VERSION_ID)]
    )
    client
  end

  def app
    {
      "type" => "apps",
      "id" => APP_ID,
      "attributes" => { "name" => "Example", "bundleId" => "com.example.app" }
    }
  end

  def version(number, state, created_date, id)
    {
      "type" => "appStoreVersions",
      "id" => id,
      "attributes" => {
        "platform" => "IOS",
        "versionString" => number,
        "appVersionState" => state,
        "createdDate" => created_date
      }
    }
  end

  def submission(id, state, submitted_date)
    {
      "type" => "reviewSubmissions",
      "id" => id,
      "attributes" => { "platform" => "IOS", "state" => state, "submittedDate" => submitted_date }
    }
  end

  def review_item(id, version_id, state)
    {
      "type" => "reviewSubmissionItems",
      "id" => id,
      "attributes" => { "state" => state },
      "relationships" => {
        "appStoreVersion" => { "data" => { "type" => "appStoreVersions", "id" => version_id } }
      }
    }
  end
end
