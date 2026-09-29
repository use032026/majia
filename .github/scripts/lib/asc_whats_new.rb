# frozen_string_literal: true

require "time"
require_relative "asc_review_status"

module MajiaCI
  class ASCWhatsNewError < StandardError; end

  module ASCWhatsNew
    module_function

    LOCALE_PATTERN = /\A[a-z]{2,3}(?:-[A-Za-z0-9]{2,8})*\z/

    def sync(client:, bundle_id:, marketing_version:, release_notes:, checked_at: Time.now.utc)
      validate_release_notes!(release_notes)
      app = ASCReviewStatus.resolve_app(client, bundle_id)
      app_details = client.get(
        "/v1/apps/#{app.fetch('id')}",
        { "fields[apps]" => "name,bundleId,primaryLocale" }
      ).fetch("data")
      version = ASCReviewStatus.resolve_version(client, app.fetch("id"), marketing_version)
      observed_version = version.dig("attributes", "versionString")
      unless observed_version == marketing_version
        raise ASCWhatsNewError,
              "ASC returned App Store version #{observed_version || 'UNKNOWN'} instead of #{marketing_version}"
      end

      existing = version_localizations(client, version.fetch("id"))
      planned = plan_locales(
        client: client,
        app_id: app.fetch("id"),
        primary_locale: app_details.dig("attributes", "primaryLocale"),
        existing: existing,
        requested_locales: release_notes.keys
      )

      updated = release_notes.map do |requested_locale, whats_new|
        applied_locale = planned.fetch(requested_locale)
        localization = existing[applied_locale] || create_version_localization(
          client: client,
          version_id: version.fetch("id"),
          locale: applied_locale
        )
        existing[applied_locale] = localization
        update_and_verify(
          client: client,
          localization: localization,
          requested_locale: requested_locale,
          applied_locale: applied_locale,
          whats_new: whats_new
        )
      end

      {
        "schema_version" => 1,
        "checked_at" => checked_at.utc.iso8601,
        "app" => {
          "id" => app.fetch("id"),
          "name" => app_details.dig("attributes", "name"),
          "bundle_id" => app_details.dig("attributes", "bundleId") || bundle_id,
          "primary_locale" => app_details.dig("attributes", "primaryLocale")
        },
        "version" => {
          "id" => version.fetch("id"),
          "version_string" => observed_version,
          "app_version_state" => version.dig("attributes", "appVersionState")
        },
        "updated" => updated,
        "text_metadata_updated" => true,
        "evidence_boundary" =>
          "ASC API write-and-readback result for whatsNew only. It does not submit, approve, or release the version."
      }
    end

    def validate_release_notes!(release_notes)
      unless release_notes.is_a?(Hash) && !release_notes.empty?
        raise ASCWhatsNewError, "release notes must be a non-empty locale-to-text mapping"
      end

      release_notes.each do |locale, text|
        unless locale.is_a?(String) && locale.match?(LOCALE_PATTERN)
          raise ASCWhatsNewError, "release notes contain invalid locale #{locale.inspect}"
        end
        unless text.is_a?(String) && !text.strip.empty? && !text.include?("\0")
          raise ASCWhatsNewError, "release notes for #{locale} must be a non-empty string"
        end
      end
    end
    private_class_method :validate_release_notes!

    def version_localizations(client, version_id)
      client.paginate(
        "/v1/appStoreVersions/#{version_id}/appStoreVersionLocalizations",
        { "limit" => "200" }
      ).each_with_object({}) do |localization, result|
        result[localization.dig("attributes", "locale")] = localization
      end
    end
    private_class_method :version_localizations

    def app_info_locales(client, app_id)
      infos = client.paginate("/v1/apps/#{app_id}/appInfos", { "limit" => "200" })
      infos.flat_map do |info|
        client.paginate(
          "/v1/appInfos/#{info.fetch('id')}/appInfoLocalizations",
          { "limit" => "200" }
        ).map { |localization| localization.dig("attributes", "locale") }
      end.compact.uniq.sort
    end
    private_class_method :app_info_locales

    def plan_locales(client:, app_id:, primary_locale:, existing:, requested_locales:)
      return requested_locales.to_h { |locale| [locale, locale] } if requested_locales.all? { |locale| existing[locale] }

      allowed = app_info_locales(client, app_id)
      plan = requested_locales.each_with_object({}) do |requested, result|
        applied = if existing[requested] || allowed.include?(requested)
                    requested
                  elsif requested_locales.length == 1 && primary_locale &&
                        (existing[primary_locale] || allowed.include?(primary_locale))
                    primary_locale
                  elsif requested_locales.length == 1 && existing.length == 1
                    existing.keys.first
                  elsif requested_locales.length == 1 && allowed.length == 1
                    allowed.first
                  end
        unless applied
          available = (existing.keys + allowed).compact.uniq.sort
          raise ASCWhatsNewError,
                "cannot safely map requested locale #{requested}; available ASC locales: #{available.join(', ')}"
        end
        result[requested] = applied
      end

      duplicates = plan.values.group_by(&:itself).select { |_locale, values| values.length > 1 }.keys
      unless duplicates.empty?
        raise ASCWhatsNewError, "multiple release notes map to the same ASC locale: #{duplicates.join(', ')}"
      end
      plan
    end
    private_class_method :plan_locales

    def create_version_localization(client:, version_id:, locale:)
      client.post(
        "/v1/appStoreVersionLocalizations",
        {
          "data" => {
            "type" => "appStoreVersionLocalizations",
            "attributes" => { "locale" => locale },
            "relationships" => {
              "appStoreVersion" => {
                "data" => { "type" => "appStoreVersions", "id" => version_id }
              }
            }
          }
        }
      ).fetch("data")
    end
    private_class_method :create_version_localization

    def update_and_verify(client:, localization:, requested_locale:, applied_locale:, whats_new:)
      localization_id = localization.fetch("id")
      client.patch(
        "/v1/appStoreVersionLocalizations/#{localization_id}",
        {
          "data" => {
            "type" => "appStoreVersionLocalizations",
            "id" => localization_id,
            "attributes" => { "whatsNew" => whats_new }
          }
        }
      )
      observed = client.get("/v1/appStoreVersionLocalizations/#{localization_id}").fetch("data")
      unless observed.dig("attributes", "locale") == applied_locale &&
             observed.dig("attributes", "whatsNew") == whats_new
        raise ASCWhatsNewError, "failed to verify whatsNew for ASC locale #{applied_locale}"
      end

      {
        "requested_locale" => requested_locale,
        "applied_locale" => applied_locale,
        "fallback_used" => requested_locale != applied_locale,
        "localization_id" => localization_id,
        "whats_new" => whats_new,
        "verified" => true
      }
    end
    private_class_method :update_and_verify
  end
end
