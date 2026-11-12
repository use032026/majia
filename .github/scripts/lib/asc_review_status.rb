# frozen_string_literal: true

require "json"
require "net/http"
require "openssl"
require "time"
require "uri"
require_relative "asc_private_key"

module MajiaCI
  class ASCStatusError < StandardError; end

  module ASCReviewStatus
    module_function

    API_ORIGIN = "https://api.appstoreconnect.apple.com"
    VERSION_PATTERN = /\A(?:0|[1-9]\d*)(?:\.(?:0|[1-9]\d*)){0,2}\z/
    KEY_ID_PATTERN = /\A[A-Z0-9]{10}\z/
    ISSUER_ID_PATTERN = /\A[0-9a-fA-F]{8}(?:-[0-9a-fA-F]{4}){3}-[0-9a-fA-F]{12}\z/
    BUNDLE_ID_PATTERN = /\A[A-Za-z0-9-]+(?:\.[A-Za-z0-9-]+)+\z/

    REVIEW_STATE_PRIORITY = {
      "UNRESOLVED_ISSUES" => 80,
      "IN_REVIEW" => 70,
      "WAITING_FOR_REVIEW" => 60,
      "READY_FOR_REVIEW" => 50,
      "COMPLETING" => 40,
      "CANCELING" => 30,
      "COMPLETE" => 20
    }.freeze

    def validate_inputs!(bundle_id:, marketing_version:, key_id:, issuer_id:)
      raise ASCStatusError, "IOS_BUNDLE_ID is invalid" unless bundle_id.match?(BUNDLE_ID_PATTERN)
      unless marketing_version.empty? || marketing_version.match?(VERSION_PATTERN)
        raise ASCStatusError, "marketing-version must contain one to three dot-separated integers"
      end
      raise ASCStatusError, "ASC_KEY_ID must contain 10 uppercase letters or digits" unless key_id.match?(KEY_ID_PATTERN)
      raise ASCStatusError, "ASC_ISSUER_ID must be a UUID" unless issuer_id.match?(ISSUER_ID_PATTERN)
    end

    def normalize_private_key(secret)
      ASCPrivateKey.read_p8(secret, error_class: ASCStatusError)
    end

    def jwt(key:, key_id:, issuer_id:, now: Time.now.utc)
      header = { "alg" => "ES256", "kid" => key_id, "typ" => "JWT" }
      payload = {
        "iss" => issuer_id,
        "iat" => now.to_i,
        "exp" => now.to_i + 10 * 60,
        "aud" => "appstoreconnect-v1"
      }
      signing_input = [header, payload].map { |part| base64url(JSON.generate(part)) }.join(".")
      digest = OpenSSL::Digest::SHA256.digest(signing_input)
      sequence = OpenSSL::ASN1.decode(key.dsa_sign_asn1(digest))
      signature = sequence.value.map { |integer| integer_bytes(integer.value) }.join
      "#{signing_input}.#{base64url(signature)}"
    end

    def build_status(client:, bundle_id:, marketing_version: "", checked_at: Time.now.utc)
      app = resolve_app(client, bundle_id)
      version = resolve_version(client, app.fetch("id"), marketing_version)
      build = resolve_build(client, version.fetch("id"))
      submission = nil
      submission_error = nil
      begin
        submission = resolve_review_submission(client, app.fetch("id"), version.fetch("id"))
      rescue ASCStatusError => e
        submission_error = e.message
      end

      version_attributes = version.fetch("attributes", {})
      {
        "schema_version" => 1,
        "checked_at" => checked_at.utc.iso8601,
        "requested_marketing_version" => marketing_version.empty? ? nil : marketing_version,
        "app" => {
          "id" => app.fetch("id"),
          "name" => app.dig("attributes", "name"),
          "bundle_id" => app.dig("attributes", "bundleId") || bundle_id
        },
        "version" => {
          "id" => version.fetch("id"),
          "platform" => version_attributes["platform"],
          "version_string" => version_attributes["versionString"],
          "app_version_state" => version_attributes["appVersionState"],
          "release_type" => version_attributes["releaseType"],
          "review_stage" => review_stage(version_attributes["appVersionState"]),
          "created_date" => version_attributes["createdDate"]
        },
        "build" => summarize_build(build),
        "review_submission" => submission,
        "review_submission_query_error" => submission_error,
        "evidence_boundary" =>
          "Read-only ASC snapshot. It does not build, upload, submit, release, or prove TestFlight/device availability."
      }
    end

    def build_inventory(client:, bundle_id:, marketing_version:, checked_at: Time.now.utc)
      unless marketing_version.match?(VERSION_PATTERN)
        raise ASCStatusError, "build inventory requires an exact marketing version"
      end

      app = resolve_app(client, bundle_id)
      raise ASCStatusError, "ASC app bundle ID did not match" unless app.dig("attributes", "bundleId") == bundle_id

      app_id = inventory_id(app)
      app_path = "/v1/apps/#{app_id}"
      uploads = client.paginate(
        "#{app_path}/buildUploads",
        { "fields[buildUploads]" => "cfBundleShortVersionString,cfBundleVersion,state,platform,createdDate,uploadedDate",
          "limit" => "200" }
      ).filter_map do |upload|
        attributes = upload.fetch("attributes")
        next unless inventory_field(upload, "platform") == "IOS" &&
                    inventory_field(upload, "cfBundleShortVersionString") == marketing_version

        state = attributes["state"]
        state_code = state["state"] if state.is_a?(Hash)
        unless state_code.is_a?(String) && state_code.match?(/\A[A-Z][A-Z_]*\z/)
          raise ASCStatusError, "ASC build inventory response has invalid upload state"
        end

        {
          "id" => inventory_id(upload),
          "version" => inventory_field(upload, "cfBundleVersion"),
          "state" => state_code,
          "created_date" => attributes["createdDate"],
          "uploaded_date" => attributes["uploadedDate"]
        }
      end

      versions = client.paginate(
        "#{app_path}/preReleaseVersions",
        { "fields[preReleaseVersions]" => "platform,version", "limit" => "200" }
      ).select do |version|
        inventory_field(version, "platform") == "IOS" && inventory_field(version, "version") == marketing_version
      end
      builds = versions.flat_map do |version|
        client.paginate(
          "/v1/preReleaseVersions/#{inventory_id(version)}/builds",
          { "fields[builds]" => "version,processingState,uploadedDate,expired", "limit" => "200" }
        ).map do |build|
          inventory_id(build)
          inventory_field(build, "version")
          inventory_field(build, "processingState")
          raise ASCStatusError, "ASC build is missing its expiry status" unless [true, false].include?(build.dig("attributes", "expired"))

          summarize_build(build)
        end
      end

      {
        "schema_version" => 1,
        "checked_at" => checked_at.utc.iso8601,
        "app" => { "id" => app_id, "bundle_id" => bundle_id },
        "platform" => "IOS",
        "marketing_version" => marketing_version,
        "build_uploads" => uploads,
        "prerelease_builds" => builds,
        "evidence_boundary" => "Read-only ASC inventory. Empty results do not rule out uploads not yet visible to ASC."
      }
    rescue KeyError
      raise ASCStatusError, "ASC build inventory response is missing required fields"
    end

    def inventory_field(resource, field)
      value = resource.dig("attributes", field)
      raise ASCStatusError, "ASC build inventory response has invalid #{field}" unless value.is_a?(String) && !value.empty?

      value
    end
    private_class_method :inventory_field

    def inventory_id(resource)
      id = resource["id"]
      raise ASCStatusError, "ASC build inventory response has invalid resource ID" unless id.is_a?(String) && id.match?(/\A[A-Za-z0-9_-]+\z/)

      id
    end
    private_class_method :inventory_id

    def markdown(summary)
      app = summary.fetch("app")
      version = summary.fetch("version")
      build = summary["build"] || {}
      submission = summary["review_submission"] || {}
      lines = [
        "## ASC review status",
        "",
        "- App: #{display(app['name'])} (`#{display(app['bundle_id'])}`)",
        "- Marketing version: #{display(version['version_string'])}",
        "- App Store version state: `#{display(version['app_version_state'])}`",
        "- Release type: `#{display(version['release_type'])}`",
        "- Review stage: `#{display(version['review_stage'])}`",
        "- Review submission state: `#{display(submission['state'])}`",
        "- Review item state: `#{display(submission['item_state'])}`",
        "- Build number: #{display(build['version'])}",
        "- Build processing state: `#{display(build['processing_state'])}`",
        "- Checked at: #{display(summary['checked_at'])}"
      ]
      if summary["review_submission_query_error"]
        lines << "- Review submission detail: unavailable (#{summary['review_submission_query_error']})"
      end
      lines.concat(["", "> #{summary.fetch('evidence_boundary')}", ""])
      lines.join("\n")
    end

    def review_stage(state)
      case state
      when "PREPARE_FOR_SUBMISSION" then "PREPARING"
      when "READY_FOR_REVIEW" then "READY_TO_SUBMIT"
      when "WAITING_FOR_REVIEW" then "QUEUED_FOR_REVIEW"
      when "IN_REVIEW" then "IN_REVIEW"
      when "ACCEPTED", "PENDING_APPLE_RELEASE", "PENDING_CONTRACT", "PENDING_DEVELOPER_RELEASE",
           "PROCESSING_FOR_APP_STORE", "PROCESSING_FOR_DISTRIBUTION"
        "APPROVED_PENDING_DISTRIBUTION"
      when "READY_FOR_SALE", "READY_FOR_DISTRIBUTION", "PREORDER_READY_FOR_SALE"
        "DISTRIBUTED"
      when "REJECTED", "METADATA_REJECTED", "INVALID_BINARY", "DEVELOPER_REJECTED",
           "WAITING_FOR_EXPORT_COMPLIANCE"
        "ACTION_REQUIRED"
      when "DEVELOPER_REMOVED_FROM_SALE", "REMOVED_FROM_SALE" then "REMOVED_FROM_DISTRIBUTION"
      when "REPLACED_WITH_NEW_VERSION" then "SUPERSEDED"
      else "UNKNOWN"
      end
    end

    def resolve_app(client, bundle_id)
      apps = client.paginate(
        "/v1/apps",
        {
          "filter[bundleId]" => bundle_id,
          "fields[apps]" => "name,bundleId",
          "limit" => "2"
        }
      )
      raise ASCStatusError, "ASC app not found for bundle ID #{bundle_id}" if apps.empty?
      raise ASCStatusError, "ASC returned multiple apps for bundle ID #{bundle_id}" unless apps.length == 1

      apps.first
    end

    def resolve_version(client, app_id, marketing_version)
      query = {
        "filter[platform]" => "IOS",
        "fields[appStoreVersions]" => "platform,versionString,appVersionState,releaseType,createdDate",
        "limit" => "200"
      }
      query["filter[versionString]"] = marketing_version unless marketing_version.empty?
      versions = client.paginate("/v1/apps/#{app_id}/appStoreVersions", query)
      if versions.empty?
        suffix = marketing_version.empty? ? "" : " #{marketing_version}"
        raise ASCStatusError, "ASC iOS App Store version#{suffix} was not found"
      end

      versions.max_by do |version|
        attributes = version.fetch("attributes", {})
        [version_components(attributes["versionString"]), attributes["createdDate"].to_s]
      end
    end

    def resolve_build(client, version_id)
      relationship = client.get("/v1/appStoreVersions/#{version_id}/relationships/build")
      build_id = relationship.dig("data", "id")
      return nil if build_id.nil? || build_id.empty?

      client.get(
        "/v1/builds/#{build_id}",
        { "fields[builds]" => "version,processingState,uploadedDate,expired" }
      ).fetch("data")
    end

    def resolve_review_submission(client, app_id, version_id)
      submissions = client.paginate(
        "/v1/apps/#{app_id}/reviewSubmissions",
        {
          "filter[platform]" => "IOS",
          "fields[reviewSubmissions]" => "platform,submittedDate,state",
          "limit" => "200"
        }
      )
      matches = submissions.filter_map do |submission|
        items = client.paginate(
          "/v1/reviewSubmissions/#{submission.fetch('id')}/items",
          {
            "fields[reviewSubmissionItems]" => "state,appStoreVersion",
            "limit" => "200"
          }
        )
        item = items.find do |candidate|
          candidate.dig("relationships", "appStoreVersion", "data", "id") == version_id
        end
        next unless item

        attributes = submission.fetch("attributes", {})
        {
          "id" => submission.fetch("id"),
          "state" => attributes["state"],
          "submitted_date" => attributes["submittedDate"],
          "item_id" => item.fetch("id"),
          "item_state" => item.dig("attributes", "state")
        }
      end
      matches.max_by do |submission|
        [REVIEW_STATE_PRIORITY.fetch(submission["state"], 0), submission["submitted_date"].to_s]
      end
    end

    def summarize_build(build)
      return nil unless build

      attributes = build.fetch("attributes", {})
      {
        "id" => build.fetch("id"),
        "version" => attributes["version"],
        "processing_state" => attributes["processingState"],
        "uploaded_date" => attributes["uploadedDate"],
        "expired" => attributes["expired"]
      }
    end

    def version_components(version)
      version.to_s.split(".").map(&:to_i).fill(0, version.to_s.count(".") + 1...3)
    end
    private_class_method :version_components

    def base64url(value)
      Base64.urlsafe_encode64(value, padding: false)
    end
    private_class_method :base64url

    def integer_bytes(value)
      hex = value.to_s(16)
      hex = "0#{hex}" if hex.length.odd?
      [hex].pack("H*").rjust(32, "\0")
    end
    private_class_method :integer_bytes

    def display(value)
      value.nil? || value.to_s.empty? ? "not available" : value
    end
    private_class_method :display
  end

  class ASCClient
    ASSOCIATED_ERROR_LIMIT = 8
    ASSOCIATED_ERROR_SCAN_LIMIT = 64
    ASSOCIATED_ERROR_DEPTH_LIMIT = 5
    SAFE_ERROR_FIELDS = %w[
      data attributes relationships id type
      app apps appInfo appInfos appInfoLocalizations appStoreVersion appStoreVersions
      appStoreVersionForReview appStoreVersionLocalizations appStoreReviewDetail appStoreReviewDetails
      reviewSubmission reviewSubmissions reviewSubmissionItem reviewSubmissionItems items
      version versionString platform state appVersionState releaseType submitted build builds buildNumber
      contactFirstName contactLastName contactPhone contactEmail demoAccountName demoAccountPassword demoAccountRequired notes
      appEncryptionDeclaration appEncryptionDeclarations usesNonExemptEncryption appEncryptionDeclarationState
      ageRatingDeclaration ageRatingDeclarations appStoreAgeRating ageRatingOverrideV2
      appScreenshotSets appScreenshots appPreviewSets appPreviews
      primaryCategory secondaryCategory copyright description keywords locale marketingUrl privacyPolicyUrl
      promotionalText supportUrl whatsNew usesIdfa bundleId processingState
    ].freeze
    SAFE_ERROR_PARAMETERS = %w[include sort limit cursor platform state version versionString].freeze
    SAFE_PLAIN_ERROR_CODES = %w[FORBIDDEN UNAUTHORIZED CONFLICT].freeze

    def initialize(key:, key_id:, issuer_id:)
      @key = key
      @key_id = key_id
      @issuer_id = issuer_id
    end

    def get(path, query = nil)
      request_document(:get, path, query: query)
    end

    def post(path, payload)
      request_document(:post, path, payload: payload)
    end

    def post_created(path, payload)
      request_document(:post, path, payload: payload, expected_status: 201)
    end

    def patch(path, payload)
      request_document(:patch, path, payload: payload)
    end

    def paginate(path, query = nil, max_pages: 20)
      resources = []
      target = path
      params = query
      pages = 0
      loop do
        pages += 1
        raise ASCStatusError, "ASC pagination exceeded #{max_pages} pages" if pages > max_pages

        document = get(target, params)
        data = document.fetch("data")
        raise ASCStatusError, "ASC list response data must be an array" unless data.is_a?(Array)

        resources.concat(data)
        target = document.dig("links", "next")
        break if target.nil? || target.empty?

        params = nil
      end
      resources
    end

    private

    def request_document(method, target, query: nil, payload: nil, expected_status: nil)
      uri = target.start_with?("https://") ? URI(target) : URI("#{ASCReviewStatus::API_ORIGIN}#{target}")
      unless uri.scheme == "https" && uri.host == "api.appstoreconnect.apple.com"
        raise ASCStatusError, "ASC returned an unsafe pagination URL"
      end
      uri.query = URI.encode_www_form(query) if query && !query.empty?

      request = case method
                when :get then Net::HTTP::Get.new(uri)
                when :post then Net::HTTP::Post.new(uri)
                when :patch then Net::HTTP::Patch.new(uri)
                else raise ArgumentError, "unsupported HTTP method: #{method}"
                end
      request["Authorization"] = "Bearer #{ASCReviewStatus.jwt(key: @key, key_id: @key_id, issuer_id: @issuer_id)}"
      request["Accept"] = "application/json"
      if payload
        request["Content-Type"] = "application/json"
        request.body = JSON.generate(payload)
      end
      response = Net::HTTP.start(
        uri.host, uri.port, use_ssl: true, open_timeout: 10, read_timeout: 30
      ) do |http|
        http.max_retries = 0 if expected_status
        http.request(request)
      end
      document = response.body.to_s.empty? ? {} : JSON.parse(response.body)
      if response.is_a?(Net::HTTPSuccess)
        if expected_status && response.code.to_i != expected_status
          raise ASCStatusError, "ASC expected HTTP #{expected_status}; observed #{response.code}"
        end
        return document
      end

      errors = document.is_a?(Hash) ? Array(document["errors"]).grep(Hash) : []
      details = errors.map do |error|
        [error["code"], error["title"], error["detail"]].compact.join(": ")
      end.reject(&:empty?).join("; ")
      details = "HTTP #{response.code}" if details.empty?
      associated = associated_error_details(errors)
      details += " [associated errors: #{associated.join(', ')}]" unless associated.empty?
      if expected_status
        raise ASCStatusError, "ASC request failed: HTTP #{response.code}: #{details}"
      end
      raise ASCStatusError, "ASC request failed: #{details}"
    rescue JSON::ParserError => e
      raise ASCStatusError, "ASC returned invalid JSON: #{e.message}"
    rescue SocketError, SystemCallError, Timeout::Error => e
      raise ASCStatusError, "ASC request failed: #{e.class}: #{e.message}"
    end

    def associated_error_details(errors)
      details = []
      remaining = ASSOCIATED_ERROR_SCAN_LIMIT
      visit = lambda do |value, depth|
        next if remaining.zero? || details.size >= ASSOCIATED_ERROR_LIMIT

        remaining -= 1
        next if depth > ASSOCIATED_ERROR_DEPTH_LIMIT

        case value
        when Array
          value.each do |child|
            break if remaining.zero? || details.size >= ASSOCIATED_ERROR_LIMIT

            visit.call(child, depth + 1)
          end
        when Hash
          if value.key?("code") || value.key?("meta")
            detail = associated_error_detail(value)
            details << detail if detail && !details.include?(detail)
            visit.call(associated_error_container(value), depth + 1)
          else
            value.each_value do |child|
              break if remaining.zero? || details.size >= ASSOCIATED_ERROR_LIMIT

              visit.call(child, depth + 1)
            end
          end
        end
      end
      errors.first(ASSOCIATED_ERROR_SCAN_LIMIT).each do |error|
        visit.call(associated_error_container(error), 0)
      end
      details
    end

    def associated_error_container(error)
      meta = error["meta"]
      meta["associatedErrors"] if meta.is_a?(Hash)
    end

    def associated_error_detail(error)
      code = error["code"]
      return unless code.is_a?(String) && code.bytesize <= 80 &&
                    code.match?(/\A[A-Z][A-Z0-9_]*(?:\.[A-Z0-9_]+)*\z/) &&
                    (code.include?("_") || code.include?(".") || SAFE_PLAIN_ERROR_CODES.include?(code))

      source = error["source"]
      return code unless source.is_a?(Hash)

      locations = []
      pointer = source["pointer"]
      if pointer.is_a?(String) && pointer.bytesize <= 120 && pointer.start_with?("/")
        segments = pointer.split("/", -1).drop(1)
        if segments.all? { |part| SAFE_ERROR_FIELDS.include?(part) || part.match?(/\A(?:0|[1-9]\d{0,2})\z/) }
          locations << "pointer=#{pointer}"
        end
      end
      parameter = source["parameter"]
      if parameter.is_a?(String) && parameter.bytesize <= 80
        nested = parameter.match(/\A(?:fields|filter|limit|exists)\[([A-Za-z][A-Za-z0-9]*)\]\z/)
        if SAFE_ERROR_PARAMETERS.include?(parameter) || (nested && SAFE_ERROR_FIELDS.include?(nested[1]))
          locations << "parameter=#{parameter}"
        end
      end
      locations.empty? ? code : "#{code} (#{locations.join(', ')})"
    end
  end

  ASCReadClient = ASCClient
end
