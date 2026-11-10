# frozen_string_literal: true

require_relative "asc_review_status"

module MajiaCI
  module ASCReviewDiagnostics
    module_function

    CONTACT_FIELDS = %w[contactFirstName contactLastName contactPhone contactEmail].freeze
    AGE_FIELDS = %w[
      ageAssurance parentalControls unrestrictedWebAccess userGeneratedContent messagingAndChat advertising
    ].freeze

    def read(client:, bundle_id:, marketing_version:, checked_at: Time.now.utc)
      unless marketing_version.match?(ASCReviewStatus::VERSION_PATTERN)
        raise ASCStatusError, "review diagnostics requires an exact marketing version"
      end

      app = ASCReviewStatus.resolve_app(client, bundle_id)
      unless app.dig("attributes", "bundleId") == bundle_id
        raise ASCStatusError, "ASC app bundle ID did not match"
      end

      app_id = resource_id(app)
      version = ASCReviewStatus.resolve_version(client, app_id, marketing_version)
      unless version.dig("attributes", "platform") == "IOS" &&
             version.dig("attributes", "versionString") == marketing_version
        raise ASCStatusError, "ASC did not return the exact iOS version"
      end

      version_id = resource_id(version)
      sections = {
        "review_contact" => capture { review_contact(client, version_id) },
        "build_encryption" => capture { build_encryption(client, version_id) },
        "age_rating" => capture { age_rating(client, app_id) },
        "review_drafts" => capture { review_drafts(client, app_id, version_id) }
      }
      {
        "schema_version" => 1,
        "checked_at" => checked_at.utc.iso8601,
        "app" => { "id" => app_id, "bundle_id" => bundle_id },
        "version" => {
          "id" => version_id,
          "marketing_version" => marketing_version,
          "state" => state_code(version.dig("attributes", "appVersionState"))
        },
        "complete" => sections.values.none? { |section| section["status"] == "unavailable" },
        "sections" => sections,
        "evidence_boundary" => "Read-only field presence and state snapshot. It does not establish submission eligibility."
      }
    end

    def review_contact(client, version_id)
      path = "/v1/appStoreVersions/#{version_id}"
      relationship = client.get("#{path}/relationships/appStoreReviewDetail").fetch("data")
      return { "status" => "absent" } if relationship.nil?

      detail = client.get(
        "#{path}/appStoreReviewDetail",
        { "fields[appStoreReviewDetails]" => (CONTACT_FIELDS + ["demoAccountRequired"]).join(",") }
      ).fetch("data")
      attributes = detail.fetch("attributes")
      {
        "contact_fields_present" => CONTACT_FIELDS.to_h do |field|
          value = attributes[field]
          [field, value.is_a?(String) && !value.strip.empty?]
        end,
        "demo_account_required" => boolean(attributes["demoAccountRequired"])
      }
    end

    def build_encryption(client, version_id)
      relation = client.get("/v1/appStoreVersions/#{version_id}/relationships/build").fetch("data")
      return { "status" => "absent", "build_attached" => false } if relation.nil?

      build_id = resource_id(relation)
      path = "/v1/builds/#{build_id}"
      build = client.get(path, { "fields[builds]" => "usesNonExemptEncryption" }).fetch("data")
      declaration_link = client.get("#{path}/relationships/appEncryptionDeclaration").fetch("data")
      declaration_state = nil
      if declaration_link
        declaration_id = resource_id(declaration_link)
        declaration = client.get(
          "/v1/appEncryptionDeclarations/#{declaration_id}",
          { "fields[appEncryptionDeclarations]" => "appEncryptionDeclarationState" }
        ).fetch("data")
        declaration_state = state_code(declaration.dig("attributes", "appEncryptionDeclarationState"))
      end
      {
        "build_attached" => true,
        "build_id" => build_id,
        "uses_non_exempt_encryption" => boolean(build.dig("attributes", "usesNonExemptEncryption")),
        "declaration_present" => !declaration_link.nil?,
        "declaration_state" => declaration_state
      }
    end

    def age_rating(client, app_id)
      app_infos = client.paginate(
        "/v1/apps/#{app_id}/appInfos",
        { "fields[appInfos]" => "appStoreState,state,appStoreAgeRating", "limit" => "200" }
      )
      {
        "app_infos" => app_infos.map do |info|
          path = "/v1/appInfos/#{resource_id(info)}"
          declaration_link = client.get("#{path}/relationships/ageRatingDeclaration").fetch("data")
          responses = nil
          if declaration_link
            declaration = client.get(
              "#{path}/ageRatingDeclaration",
              { "fields[ageRatingDeclarations]" => AGE_FIELDS.join(",") }
            ).fetch("data")
            attributes = declaration.fetch("attributes")
            responses = AGE_FIELDS.to_h { |field| [field, boolean(attributes[field])] }
          end
          {
            "state" => state_code(info.dig("attributes", "state") || info.dig("attributes", "appStoreState")),
            "app_store_age_rating" => state_code(info.dig("attributes", "appStoreAgeRating")),
            "declaration_present" => !declaration_link.nil?,
            "core_answers_present" => responses&.transform_values { |value| !value.nil? }
          }
        end
      }
    end

    def review_drafts(client, app_id, version_id)
      submissions = client.paginate(
        "/v1/apps/#{app_id}/reviewSubmissions",
        {
          "filter[platform]" => "IOS",
          "fields[reviewSubmissions]" => "platform,state,appStoreVersionForReview",
          "include" => "appStoreVersionForReview",
          "fields[appStoreVersions]" => "versionString",
          "limit" => "200"
        }
      )
      matches = []
      empty_drafts = 0
      unverified_empty_drafts = 0
      submissions.each do |submission|
        state = state_code(submission.dig("attributes", "state"))
        id = resource_id(submission)
        relationship = submission.dig("relationships", "appStoreVersionForReview")
        direct_link = relationship&.fetch("data", nil)
        direct_target = direct_link && resource_id(direct_link) == version_id
        items = client.paginate(
          "/v1/reviewSubmissions/#{id}/items",
          {
            "fields[reviewSubmissionItems]" => "state,appStoreVersion",
            "include" => "appStoreVersion",
            "fields[appStoreVersions]" => "versionString",
            "limit" => "200"
          }
        )
        if state == "READY_FOR_REVIEW" && items.empty?
          if relationship.nil? || !relationship.key?("data")
            unverified_empty_drafts += 1
          elsif direct_link.nil?
            empty_drafts += 1
          end
        end
        target_items = items.select do |item|
          item.dig("relationships", "appStoreVersion", "data", "id") == version_id
        end
        next unless direct_target || !target_items.empty?

        matches << {
          "state" => state,
          "version_linked_directly" => !!direct_target,
          "item_states" => target_items.map { |item| state_code(item.dig("attributes", "state")) }
        }
      end
      {
        "target_submissions" => matches,
        "empty_ready_drafts" => empty_drafts,
        "ready_drafts_with_unknown_version_link" => unverified_empty_drafts
      }
    end

    def capture
      { "status" => "observed" }.merge(yield)
    rescue ASCStatusError, KeyError, TypeError
      # Never expose the API response body, which can contain private fields.
      { "status" => "unavailable" }
    end
    private_class_method :capture

    def resource_id(resource)
      id = resource.fetch("id")
      unless id.is_a?(String) && id.match?(/\A[A-Za-z0-9_-]+\z/)
        raise ASCStatusError, "ASC returned an invalid resource ID"
      end

      id
    end
    private_class_method :resource_id

    def state_code(value)
      value if value.is_a?(String) && value.match?(/\A[A-Z][A-Z0-9_]*\z/)
    end
    private_class_method :state_code

    def boolean(value)
      value if value == true || value == false
    end
    private_class_method :boolean
  end
end
