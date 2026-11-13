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

  def test_associated_error_codes_and_schema_paths_are_retained_without_raw_metadata
    response = Net::HTTPConflict.new("1.1", "409", "Conflict")
    response.body = JSON.generate("errors" => [{
      "code" => "STATE_ERROR.ENTITY_STATE_INVALID",
      "title" => "Version cannot be reviewed",
      "detail" => "See associated errors",
      "meta" => { "associatedErrors" => {
        "/appStoreVersions/dynamic-id" => [{
          "code" => "ENTITY_ERROR.ATTRIBUTE.REQUIRED",
          "title" => "Private contact name",
          "detail" => "Private contact data",
          "source" => { "pointer" => "/data/attributes/contactEmail" },
          "meta" => { "associatedErrors" => {
            "https://example.invalid/private-resource" => [{
              "code" => "PARAMETER_ERROR.INVALID",
              "source" => { "parameter" => "filter[versionString]" }
            }]
          } }
        }, {
          "code" => "STATE_ERROR.ENTITY_NOT_FOUND",
          "source" => {
            "pointer" => "/data/attributes/PrivateName",
            "parameter" => "filter[contactEmail]=private@example.invalid"
          },
          "links" => { "about" => "https://example.invalid/private-resource" }
        }, {
          "code" => "BEARER-TOKEN-REDACTED",
          "source" => { "pointer" => "/data/attributes/demoAccountPassword" }
        }]
      } }
    }])
    response.instance_variable_set(:@read, true)

    with_fake_http(response) do |client, http|
      error = assert_raises(MajiaCI::ASCStatusError) do
        client.post("/v1/reviewSubmissionItems", {})
      end
      assert_equal(
        "ASC request failed: STATE_ERROR.ENTITY_STATE_INVALID: Version cannot be reviewed: See associated errors " \
        "[associated errors: ENTITY_ERROR.ATTRIBUTE.REQUIRED (pointer=/data/attributes/contactEmail), " \
        "PARAMETER_ERROR.INVALID (parameter=filter[versionString]), STATE_ERROR.ENTITY_NOT_FOUND]",
        error.message
      )
      assert_equal 1, http.requests.length
    end
  end

  def test_malformed_and_excess_associated_errors_do_not_replace_the_outer_error
    response = Net::HTTPConflict.new("1.1", "409", "Conflict")
    nested = Array.new(12) do |index|
      {
        "code" => "ENTITY_ERROR.FIELD_#{index}",
        "source" => { "pointer" => "/" + "attributes/" * 30, "parameter" => ["limit"] }
      }
    end
    response.body = JSON.generate("errors" => [
      { "code" => "STATE_ERROR.ENTITY_STATE_INVALID", "meta" => "malformed" },
      { "code" => "STATE_ERROR.OTHER", "meta" => { "associatedErrors" => [
        nil, "malformed", { "code" => "ENTITY_ERROR." + "A" * 100 },
        { "code" => { "private" => "secret" } }, *nested
      ] } }
    ])
    response.instance_variable_set(:@read, true)

    with_fake_http(response) do |client, http|
      error = assert_raises(MajiaCI::ASCStatusError) do
        client.post_created("/v1/appStoreVersionReleaseRequests", {})
      end
      assert_match(/\AASC request failed: HTTP 409: STATE_ERROR.ENTITY_STATE_INVALID; STATE_ERROR.OTHER/, error.message)
      assert_equal (0..7).to_a, error.message.scan(/ENTITY_ERROR\.FIELD_(\d+)/).flatten.map(&:to_i)
      refute_includes error.message, "pointer="
      refute_includes error.message, "parameter="
      refute_includes error.message, "secret"
      assert_equal 0, http.max_retries
      assert_equal 1, http.requests.length
    end
  end

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

  def test_post_created_accepts_only_201_and_disables_http_retry
    [201, 200].each do |code|
      response = (code == 201 ? Net::HTTPCreated : Net::HTTPOK).new("1.1", code.to_s, "OK")
      response.body = JSON.generate("data" => { "type" => "appStoreVersionReleaseRequests", "id" => "release-1" })
      response.instance_variable_set(:@read, true)
      with_fake_http(response) do |client, http|
        if code == 201
          assert_equal "release-1", client.post_created("/v1/appStoreVersionReleaseRequests", {}).dig("data", "id")
        else
          error = assert_raises(MajiaCI::ASCStatusError) do
            client.post_created("/v1/appStoreVersionReleaseRequests", {})
          end
          assert_includes error.message, "expected HTTP 201"
        end
        assert_equal 0, http.max_retries
        assert_equal 1, http.requests.length
        assert_equal "POST", http.requests.first.method
      end
    end
  end

  def test_post_created_timeout_does_not_retry
    with_fake_http(Timeout::Error.new("simulated timeout")) do |client, http|
      assert_raises(MajiaCI::ASCStatusError) do
        client.post_created("/v1/appStoreVersionReleaseRequests", {})
      end
      assert_equal 0, http.max_retries
      assert_equal 1, http.requests.length
    end
  end

  def test_post_created_forbidden_is_reported_without_retry
    response = Net::HTTPForbidden.new("1.1", "403", "Forbidden")
    response.body = JSON.generate("errors" => [{ "code" => "FORBIDDEN", "title" => "Not authorized" }])
    response.instance_variable_set(:@read, true)
    with_fake_http(response) do |client, http|
      error = assert_raises(MajiaCI::ASCPermissionError) do
        client.post_created("/v1/appStoreVersionReleaseRequests", {})
      end
      assert_includes error.message, "HTTP 403"
      assert_equal 0, http.max_retries
      assert_equal 1, http.requests.length
    end
  end

  def test_get_keeps_its_existing_transport_retry_setting
    response = Net::HTTPOK.new("1.1", "200", "OK")
    response.body = JSON.generate("data" => { "id" => "version-1" })
    response.instance_variable_set(:@read, true)
    with_fake_http(response) do |client, http|
      assert_equal "version-1", client.get("/v1/appStoreVersions/version-1").dig("data", "id")
      assert_equal 1, http.max_retries
      assert_equal "GET", http.requests.first.method
    end
  end

  def test_private_key_normalization_accepts_all_supported_secret_representations
    pem = OpenSSL::PKey::EC.generate("prime256v1").to_pem
    representations = [
      pem,
      Base64.strict_encode64(pem),
      pem.gsub("\n", "\\n"),
      pem.gsub("\n", "\\r\\n"),
      pem.to_json,
      "ASC_API_KEY_P8=#{pem}",
      Base64.strict_encode64(Base64.strict_encode64(pem)),
      pem.lines.map(&:strip).join(" ")
    ]

    public_keys = representations.map { |value| Status.normalize_private_key(value).public_key.to_octet_string(:uncompressed) }
    assert_equal 1, public_keys.uniq.length
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
    assert_equal "MANUAL", summary.dig("version", "release_type")
    assert_includes Status.markdown(summary), "- Release type: `MANUAL`"
    version_query = client.calls.find do |_method, path, _query|
      path == "/v1/apps/#{APP_ID}/appStoreVersions"
    end.last
    assert_includes version_query.fetch("fields[appStoreVersions]").split(","), "releaseType"
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

    %w[
      tripcost-production hearthio-production sdpacket-production photo-production
      plotproof_lab-production
    ].each do |environment|
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

  def with_fake_http(response)
    http = Struct.new(:result, :max_retries, :requests) do
      def request(value)
        requests << value
        raise result if result.is_a?(Exception)

        result
      end
    end.new(response, 1, [])
    client = MajiaCI::ASCClient.new(
      key: OpenSSL::PKey::EC.generate("prime256v1"),
      key_id: "ABCDEF1234",
      issuer_id: "12345678-1234-1234-1234-1234567890ab"
    )
    original_start = Net::HTTP.method(:start)
    Net::HTTP.define_singleton_method(:start) { |*_arguments, **_options, &block| block.call(http) }
    yield client, http
  ensure
    Net::HTTP.define_singleton_method(:start, original_start) if original_start
  end

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
        "releaseType" => "MANUAL",
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

class ASCBuildInventoryTest < Minitest::Test
  Bundle = "com.example.app"
  Status = MajiaCI::ASCReviewStatus

  class PageClient < MajiaCI::ASCReadClient
    attr_reader :calls

    def initialize(pages)
      @pages = pages
      @calls = []
    end

    def get(path, query = nil)
      @calls << [path, query]
      page = @pages.fetch(path)
      raise page if page.is_a?(Exception)

      page
    end
  end

  def test_exact_ios_inventory_walks_pages_without_an_app_store_version
    client = inventory_client(
      "/v1/apps/app-1/buildUploads" => page([
        upload("upload-1", "1.0.2", "PROCESSING"),
        upload("other-version", "1.0.1", "COMPLETE"),
        upload("other-platform", "1.0.2", "COMPLETE", platform: "MAC_OS")
      ], next_page: "/uploads-page-2"),
      "/uploads-page-2" => page([
        upload("upload-2", "1.0.2", "FAILED"),
        upload("upload-3", "1.0.2", "COMPLETE")
      ]),
      "/v1/apps/app-1/preReleaseVersions" => page([
        resource("beta-old", "version" => "1.0.1", "platform" => "IOS")
      ], next_page: "/betas-page-2"),
      "/betas-page-2" => page([
        resource("beta-mac", "version" => "1.0.2", "platform" => "MAC_OS"),
        resource("beta-ios", "version" => "1.0.2", "platform" => "IOS")
      ]),
      "/v1/preReleaseVersions/beta-ios/builds" => page([
        build("build-1", "1", "VALID", false)
      ], next_page: "/builds-page-2"),
      "/builds-page-2" => page([
        build("build-2", "2", "FAILED", true)
      ])
    )

    inventory = fetch_inventory(client)
    assert_equal "1.0.2", inventory["marketing_version"]
    assert_equal %w[PROCESSING FAILED COMPLETE], inventory["build_uploads"].map { |upload| upload["state"] }
    assert_equal %w[VALID FAILED], inventory["prerelease_builds"].map { |build| build["processing_state"] }
    assert_equal [false, true], inventory["prerelease_builds"].map { |build| build["expired"] }
    assert_equal({ "id" => "app-1", "bundle_id" => Bundle }, inventory["app"])
    refute_includes JSON.generate(inventory), "private Apple diagnostics"
    refute client.calls.any? { |path, _| path.include?("appStoreVersions") }
    upload_query = client.calls.assoc("/v1/apps/app-1/buildUploads").last
    refute upload_query.keys.any? { |key| key.start_with?("filter[") }
    assert_includes client.calls, ["/uploads-page-2", nil]
    assert_includes client.calls, ["/betas-page-2", nil]
    assert_includes client.calls, ["/builds-page-2", nil]
  end

  def test_no_uploads_or_prerelease_versions_returns_observed_empty_arrays
    inventory = fetch_inventory(inventory_client)
    assert_empty inventory["build_uploads"]
    assert_empty inventory["prerelease_builds"]
    assert_match(/not yet visible/, inventory["evidence_boundary"])
  end

  def test_second_page_failure_does_not_return_partial_inventory
    client = inventory_client(
      "/v1/apps/app-1/buildUploads" => page([upload("upload-1", "1.0.2", "PROCESSING")], next_page: "/failed"),
      "/failed" => MajiaCI::ASCStatusError.new("ASC request failed: HTTP 403")
    )

    assert_raises(MajiaCI::ASCStatusError) { fetch_inventory(client) }
  end

  def test_incomplete_upload_resource_fails_closed
    client = inventory_client(
      "/v1/apps/app-1/buildUploads" => page([
        resource("upload-1", "platform" => "IOS", "cfBundleShortVersionString" => "1.0.2")
      ])
    )

    assert_raises(MajiaCI::ASCStatusError) { fetch_inventory(client) }
  end

  def test_upload_state_without_a_state_code_fails_closed
    malformed = upload("upload-1", "1.0.2", "FAILED")
    malformed.fetch("attributes")["state"] = { "errors" => [{ "description" => "private Apple diagnostics" }] }
    client = inventory_client("/v1/apps/app-1/buildUploads" => page([malformed]))

    error = assert_raises(MajiaCI::ASCStatusError) { fetch_inventory(client) }
    refute_includes error.message, "private Apple diagnostics"
  end

  def test_requires_exact_version_before_request
    client = inventory_client
    assert_raises(MajiaCI::ASCStatusError) do
      Status.build_inventory(client: client, bundle_id: Bundle, marketing_version: "")
    end
    assert_empty client.calls
  end

  private

  def fetch_inventory(client)
    Status.build_inventory(client: client, bundle_id: Bundle, marketing_version: "1.0.2")
  end

  def inventory_client(overrides = {})
    PageClient.new({
      "/v1/apps" => page([resource("app-1", "bundleId" => Bundle)]),
      "/v1/apps/app-1/buildUploads" => page([]),
      "/v1/apps/app-1/preReleaseVersions" => page([])
    }.merge(overrides))
  end

  def page(data, next_page: nil)
    { "data" => data, "links" => { "next" => next_page } }
  end

  def resource(id, attributes)
    { "id" => id, "attributes" => attributes }
  end

  def upload(id, version, state, platform: "IOS")
    resource(id, {
      "cfBundleShortVersionString" => version,
      "cfBundleVersion" => "1",
      "state" => {
        "state" => state,
        "errors" => [{ "description" => "private Apple diagnostics" }],
        "warnings" => [{ "description" => "private Apple diagnostics" }]
      },
      "platform" => platform
    })
  end

  def build(id, version, state, expired)
    resource(id, "version" => version, "processingState" => state, "expired" => expired)
  end
end
