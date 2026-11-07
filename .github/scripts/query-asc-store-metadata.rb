#!/usr/bin/env ruby
# frozen_string_literal: true

require "digest"
require "json"
require "optparse"
require "yaml"
require_relative "lib/asc_review_status"

module MajiaCI
  # Read-only evidence and a submission gate after an interrupted metadata update.
  module ASCStoreMetadata
    module_function

    EDITABLE = %w[PREPARE_FOR_SUBMISSION READY_FOR_REVIEW DEVELOPER_REJECTED METADATA_REJECTED REJECTED INVALID_BINARY WAITING_FOR_EXPORT_COMPLIANCE].freeze
    INFO_FIELDS = { "name" => "name", "subtitle" => "subtitle", "privacy_policy_url" => "privacyPolicyUrl", "privacy_choices_url" => "privacyChoicesUrl" }.freeze
    VERSION_FIELDS = { "description" => "description", "keywords" => "keywords", "marketing_url" => "marketingUrl", "promotional_text" => "promotionalText", "support_url" => "supportUrl", "whats_new" => "whatsNew" }.freeze
    COLLECTIONS = {
      "screenshots" => ["appScreenshotSets", "appScreenshots", "screenshotDisplayType", "assetDeliveryState"],
      "previews" => ["appPreviewSets", "appPreviews", "previewType", "videoDeliveryState"]
    }.freeze

    def read(client:, bundle_id:, marketing_version:)
      result = { "schema_version" => 1, "checked_at" => Time.now.utc.iso8601, "errors" => [], "app_infos" => [], "localizations" => [] }
      capture(result, "/v1/apps") do
        result["app"] = ASCReviewStatus.resolve_app(client, bundle_id)
      end
      app_id = result.dig("app", "id")
      return result unless app_id

      capture(result, "/v1/apps/#{app_id}/appInfos") do
        client.paginate("/v1/apps/#{app_id}/appInfos", { "limit" => "200" }).each do |info|
          row = { "id" => info.fetch("id"), "attributes" => info.fetch("attributes", {}), "localizations" => [] }
          result["app_infos"] << row
          path = "/v1/appInfos/#{info.fetch('id')}/appInfoLocalizations"
          capture(result, path) do
            row["localizations"] = client.paginate(path, { "limit" => "200" }).map do |locale|
              { "id" => locale.fetch("id"), "attributes" => locale.fetch("attributes", {}).select { |key, _| (INFO_FIELDS.values + ["locale"]).include?(key) } }
            end
          end
        end
      end
      capture(result, "/v1/apps/#{app_id}/appStoreVersions") do
        version = ASCReviewStatus.resolve_version(client, app_id, marketing_version)
        raise ASCStatusError, "ASC returned a different marketing version" unless version.dig("attributes", "versionString") == marketing_version

        result["version"] = client.get("/v1/appStoreVersions/#{version.fetch('id')}").fetch("data")
      end
      version_id = result.dig("version", "id")
      return result unless version_id

      capture(result, "/v1/appStoreVersions/#{version_id}/relationships/build") do
        result["build"] = ASCReviewStatus.resolve_build(client, version_id)
      end
      capture(result, "/v1/appStoreVersions/#{version_id}/appStoreVersionLocalizations") do
        client.paginate("/v1/appStoreVersions/#{version_id}/appStoreVersionLocalizations", { "limit" => "200" }).each do |locale|
          row = { "id" => locale.fetch("id"), "attributes" => locale.fetch("attributes", {}).select { |key, _| (VERSION_FIELDS.values + ["locale"]).include?(key) }, "media" => {} }
          result["localizations"] << row
          COLLECTIONS.each do |kind, (sets, assets, display, state)|
            row["media"][kind] = []
            path = "/v1/appStoreVersionLocalizations/#{locale.fetch('id')}/#{sets}"
            capture(result, path) do
              client.paginate(path, { "limit" => "200" }).each do |set|
                group = { "id" => set.fetch("id"), "display_type" => set.dig("attributes", display), "assets" => [], "ordered_ids" => [] }
                row["media"][kind] << group
                asset_path = "/v1/#{sets}/#{set.fetch('id')}/#{assets}"
                capture(result, asset_path) do
                  group["assets"] = client.paginate(asset_path, { "limit" => "200" }).map do |asset|
                    { "id" => asset.fetch("id"), "attributes" => asset.fetch("attributes", {}).select { |key, _| ["fileName", "fileSize", "sourceFileChecksum", state, "assetDeliveryState"].include?(key) } }
                  end
                end
                order_path = "/v1/#{sets}/#{set.fetch('id')}/relationships/#{assets}"
                capture(result, order_path) { group["ordered_ids"] = client.get(order_path).fetch("data").map { |item| item.fetch("id") } }
              end
            end
          end
        end
      end
      result
    end

    def capture(result, path)
      yield
    rescue StandardError => e
      result["errors"] << { "path" => path, "error" => e.message }
    end

    def verify(result, manifest:, workspace:, expected_build_number:, text:, media:)
      failures = result.fetch("errors").map { |error| "#{error.fetch('path')}: #{error.fetch('error')}" }
      build = result["build"]
      failures << "attached build must be #{expected_build_number}, VALID and unexpired" unless build &&
        build.dig("attributes", "version") == expected_build_number && build.dig("attributes", "processingState") == "VALID" && !build.dig("attributes", "expired")

      if text
        unless (manifest.keys - %w[uses_non_exempt_encryption app_info_localizations localizations media copyright uses_idfa]).empty?
          failures << "manifest includes text fields unsupported by this readback verifier"
        end
        %w[copyright uses_idfa].each do |key|
          api_key = key == "uses_idfa" ? "usesIdfa" : key
          failures << "version.#{api_key} differs" if manifest.key?(key) && result.dig("version", "attributes", api_key) != manifest[key]
        end
        requested = manifest.fetch("app_info_localizations", {})
        unless requested.empty?
          editable = result.fetch("app_infos").select { |info| EDITABLE.include?(info.dig("attributes", "state") || info.dig("attributes", "appStoreState")) }
          if editable.length != 1
            failures << "expected exactly one editable App Info, found #{editable.length}"
          else
            verify_locales(editable.first.fetch("localizations"), requested, INFO_FIELDS, "App Info", failures)
          end
        end
        verify_locales(result.fetch("localizations"), manifest.fetch("localizations", {}), VERSION_FIELDS, "version", failures)
      end
      if media
        manifest.fetch("media", {}).each do |locale, kinds|
          remote = result.fetch("localizations").find { |row| row.dig("attributes", "locale") == locale }
          kinds.each do |kind, collections|
            collections.each do |display_type, files|
              label = "#{locale}.#{kind}.#{display_type}"
              matches = Array(remote&.dig("media", kind)).select { |set| set["display_type"] == display_type }
              if matches.length != 1
                failures << "#{label}: expected one set, found #{matches.length}"
                next
              end
              set = matches.first
              ids = set.fetch("ordered_ids")
              assets = set.fetch("assets").to_h { |asset| [asset.fetch("id"), asset] }
              unless ids.length == files.length && ids.uniq.length == ids.length && assets.keys.sort == ids.sort
                failures << "#{label}: asset count or order relationship is incomplete"
                next
              end
              files.each_with_index do |relative, index|
                path = File.realpath(File.expand_path(relative, workspace))
                raise ASCStatusError, "media path is outside workspace" unless path.start_with?(File.realpath(workspace) + File::SEPARATOR) && File.file?(path)

                attrs = assets.fetch(ids[index]).fetch("attributes")
                state_key = COLLECTIONS.fetch(kind).last
                state = attrs.dig(state_key, "state") || attrs.dig("assetDeliveryState", "state")
                matches_file = attrs["fileName"] == File.basename(path) && attrs["fileSize"] == File.size(path) &&
                  attrs["sourceFileChecksum"].to_s.downcase == Digest::MD5.file(path).hexdigest && state == "COMPLETE"
                failures << "#{label}[#{index}]: file, order, checksum or COMPLETE state differs" unless matches_file
              end
            end
          end
        end
      end
      result["verification"] = { "passed" => failures.empty?, "failures" => failures, "text_checked" => text, "media_checked" => media, "expected_build_number" => expected_build_number }
      failures.empty?
    end

    def verify_locales(observed, requested, fields, label, failures)
      requested.each do |locale, attrs|
        matches = observed.select { |row| row.dig("attributes", "locale") == locale }
        if matches.length != 1
          failures << "#{label}.#{locale}: expected one localization, found #{matches.length}"
          next
        end
        attrs.each do |key, expected|
          failures << "#{label}.#{locale}.#{key} differs" unless fields.key?(key) && matches.first.dig("attributes", fields[key]) == expected
        end
      end
    end

    def main(argv)
      options = { verify_text: "false", verify_media: "false" }
      OptionParser.new do |parser|
        %w[bundle-id marketing-version output verify-manifest verify-text verify-media expected-build-number].each do |key|
          parser.on("--#{key} VALUE") { |value| options[key.tr('-', '_').to_sym] = value }
        end
      end.parse!(argv)
      %i[bundle_id marketing_version output].each { |key| raise ASCStatusError, "#{key} is required" if options[key].to_s.empty? }
      key_id = ENV.fetch("ASC_KEY_ID"); issuer_id = ENV.fetch("ASC_ISSUER_ID")
      ASCReviewStatus.validate_inputs!(bundle_id: options[:bundle_id], marketing_version: options[:marketing_version], key_id: key_id, issuer_id: issuer_id)
      %i[verify_text verify_media].each { |key| raise ASCStatusError, "#{key} must be true or false" unless %w[true false].include?(options[key]) }
      if options[:verify_manifest] && !options[:expected_build_number].to_s.match?(/\A[1-9]\d*\z/)
        raise ASCStatusError, "expected-build-number is required for verification"
      end
      key = ASCReviewStatus.normalize_private_key(ENV.fetch("ASC_API_KEY_P8"))
      client = ASCReadClient.new(key: key, key_id: key_id, issuer_id: issuer_id)
      result = read(client: client, bundle_id: options[:bundle_id], marketing_version: options[:marketing_version])
      if options[:verify_manifest]
        manifest = YAML.safe_load(File.read(options[:verify_manifest], encoding: "UTF-8"), permitted_classes: [], aliases: false)
        verify(result, manifest: manifest, workspace: ENV.fetch("GITHUB_WORKSPACE", Dir.pwd), expected_build_number: options[:expected_build_number], text: options[:verify_text] == "true", media: options[:verify_media] == "true")
      end
      File.open(options[:output], "w", 0o600) { |file| file.write(JSON.pretty_generate(result) + "\n") }
      ok = result.fetch("errors").empty? && result.dig("verification", "passed") != false
      puts "Read-only ASC metadata snapshot: #{ok ? 'PASS' : 'FAIL'}; output=#{options[:output]}"
      warn result.dig("verification", "failures").join("\n") if result.dig("verification", "passed") == false
      ok ? 0 : 1
    rescue StandardError => e
      if options && options[:output] && result
        result["errors"] << { "error" => e.message }
        File.open(options[:output], "w", 0o600) { |file| file.write(JSON.pretty_generate(result) + "\n") }
      end
      warn e.message
      1
    end
  end
end

exit MajiaCI::ASCStoreMetadata.main(ARGV) if $PROGRAM_NAME == __FILE__
