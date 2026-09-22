# frozen_string_literal: true

require "base64"
require "json"
require "openssl"
require "yaml"

module MajiaCI
  class ReleaseInputError < StandardError; end

  module EnvironmentIOSRelease
    module_function

    LOCALE_PATTERN = /\A[a-z]{2,3}(?:-[A-Za-z0-9]{2,8})*\z/
    SAFE_NAME_PATTERN = /\A[A-Za-z0-9_.+ -]+\z/
    BUNDLE_SUFFIX_PATTERN = /\A(?:|\.[A-Za-z0-9-]+(?:\.[A-Za-z0-9-]+)*)\z/
    VERSION_PATTERN = /\A(?:0|[1-9]\d*)\.(?:0|[1-9]\d*)\.(?:0|[1-9]\d*)\z/

    def boolean(value, name)
      return true if value == "true"
      return false if value == "false"

      raise ReleaseInputError, "#{name} must be true or false"
    end

    def validate_release_switches!(
      upload_to_asc:, auto_create_store_version:, update_asc_text_metadata:, replace_asc_media:
    )
      if auto_create_store_version && !upload_to_asc
        raise ReleaseInputError, "auto_create_store_version=true requires upload_to_asc=true"
      end
      if update_asc_text_metadata && !auto_create_store_version
        raise ReleaseInputError,
              "update_asc_text_metadata=true requires auto_create_store_version=true"
      end
      if replace_asc_media && !auto_create_store_version
        raise ReleaseInputError, "replace_asc_media=true requires auto_create_store_version=true"
      end
    end

    def parse_targets(json)
      targets = JSON.parse(json)
      unless targets.is_a?(Array) && !targets.empty?
        raise ReleaseInputError, "targets JSON must be a non-empty array"
      end

      targets.map.with_index do |target, index|
        unless target.is_a?(Hash) && target.keys.sort == %w[profile_alias suffix target]
          raise ReleaseInputError,
                "targets[#{index}] must contain only suffix, target, and profile_alias"
        end
        suffix = target.fetch("suffix")
        name = target.fetch("target")
        profile_alias = target.fetch("profile_alias")
        unless suffix.is_a?(String) && suffix.match?(BUNDLE_SUFFIX_PATTERN)
          raise ReleaseInputError, "targets[#{index}].suffix is invalid"
        end
        unless name.is_a?(String) && name.match?(SAFE_NAME_PATTERN)
          raise ReleaseInputError, "targets[#{index}].target is invalid"
        end
        unless profile_alias.is_a?(String) && profile_alias.match?(/\A[a-z0-9][a-z0-9_-]*\z/)
          raise ReleaseInputError, "targets[#{index}].profile_alias is invalid"
        end
        target
      end
    rescue JSON::ParserError => e
      raise ReleaseInputError, "targets JSON is invalid: #{e.message}"
    end

    def build_metadata(template_path:, release_notes_json:, update_text_metadata:)
      template = YAML.safe_load(File.read(template_path, encoding: "UTF-8"), permitted_classes: [], aliases: false)
      unless template.is_a?(Hash)
        raise ReleaseInputError, "App Store metadata template root must be a mapping"
      end
      release_notes = JSON.parse(release_notes_json)
      unless release_notes.is_a?(Hash)
        raise ReleaseInputError, "release_notes_json must be a locale-to-text mapping"
      end
      if !release_notes.empty? && !update_text_metadata
        raise ReleaseInputError,
              "non-empty release_notes_json requires update_asc_text_metadata=true"
      end

      localizations = release_notes.each_with_object({}) do |(locale, notes), result|
        unless locale.is_a?(String) && locale.match?(LOCALE_PATTERN)
          raise ReleaseInputError, "release_notes_json contains invalid locale #{locale.inspect}"
        end
        unless notes.is_a?(String) && !notes.strip.empty? && !notes.include?("\0")
          raise ReleaseInputError, "release_notes_json[#{locale}] must be a non-empty string"
        end
        result[locale] = { "whats_new" => notes }
      end

      metadata = deep_stringify_keys(template)
      metadata["uses_non_exempt_encryption"] = false unless metadata.key?("uses_non_exempt_encryption")
      unless localizations.empty?
        existing_localizations = metadata["localizations"]
        unless existing_localizations.nil? || existing_localizations.is_a?(Hash)
          raise ReleaseInputError, "metadata template localizations must be a mapping"
        end
        metadata["localizations"] ||= {}
        localizations.each do |locale, attributes|
          existing_locale = metadata["localizations"][locale]
          unless existing_locale.nil? || existing_locale.is_a?(Hash)
            raise ReleaseInputError, "metadata template localizations.#{locale} must be a mapping"
          end
          metadata["localizations"][locale] ||= {}
          metadata["localizations"][locale].merge!(attributes)
        end
      end
      metadata
    rescue JSON::ParserError => e
      raise ReleaseInputError, "release_notes_json is invalid JSON: #{e.message}"
    rescue Psych::Exception => e
      raise ReleaseInputError, "App Store metadata template is invalid YAML: #{e.message}"
    end

    def deep_stringify_keys(value)
      case value
      when Hash
        value.each_with_object({}) do |(key, child), result|
          result[key.to_s] = deep_stringify_keys(child)
        end
      when Array
        value.map { |child| deep_stringify_keys(child) }
      else
        value
      end
    end

    def normalize_p8(secret)
      compact = secret.to_s.strip
      raise ReleaseInputError, "ASC_API_KEY_P8 is required when upload_to_asc=true" if compact.empty?

      key_bytes = if compact.match?(/-----BEGIN (?:EC )?PRIVATE KEY-----/)
                    compact.end_with?("\n") ? compact : "#{compact}\n"
                  else
                    Base64.strict_decode64(compact.gsub(/\s+/, ""))
                  end
      key = OpenSSL::PKey.read(key_bytes)
      unless key.is_a?(OpenSSL::PKey::EC) && key.private? && key.group.curve_name == "prime256v1"
        raise ReleaseInputError, "ASC_API_KEY_P8 must contain a P-256 EC private key"
      end

      Base64.strict_encode64(key_bytes)
    rescue ArgumentError, OpenSSL::PKey::PKeyError => e
      raise ReleaseInputError, "ASC_API_KEY_P8 is invalid: #{e.message}"
    end

    def build_config(
      app_name:, team_id:, bundle_id:, scheme:, project_directory:, container_path:,
      targets:, upload_to_asc:, auto_create_store_version:, metadata_path:
    )
      {
        "schema_version" => 2,
        "release" => {
          "allowed_events" => ["workflow_dispatch"],
          "allowed_ref_patterns" => ["refs/heads/main"]
        },
        "app" => {
          "name" => app_name,
          "team_id" => team_id,
          "asc_app_id" => "0",
          "primary_bundle_id" => bundle_id,
          "bundle_ids" => targets.map do |target|
            {
              "bundle_id" => "#{bundle_id}#{target.fetch('suffix')}",
              "target" => target.fetch("target"),
              "profile_alias" => target.fetch("profile_alias")
            }
          end
        },
        "flutter" => {
          "project_directory" => project_directory,
          "version" => "3.35.7",
          "channel" => "stable",
          "architecture" => "arm64",
          "sdk_sha256" => "4d7aaadc4893f9216d4e2ecbe0e8fb4213e9bd49d29fd5f441f34fcc05758e2b"
        },
        "build" => {
          "container_type" => "workspace",
          "container_path" => container_path,
          "scheme" => scheme,
          "configuration" => "Release",
          "runner" => "macos-26",
          "xcode_path" => "/Applications/Xcode_26.4.app",
          "dependency_mode" => "flutter",
          "dependency_command" => ""
        },
        "versioning" => {
          "marketing_version_source" => "input",
          "build_number_strategy" => upload_to_asc ? "asc_increment" : "github_run_number",
          "build_number_override_allowed" => true
        },
        "export" => {
          "method" => "app-store-connect",
          "upload_symbols" => true,
          "strip_swift_symbols" => true
        },
        "upload" => {
          "enabled_by_default" => false,
          "asc_key_type" => "team",
          "wait_level" => "processing_complete",
          "timeout_minutes" => 90,
          "poll_interval_seconds" => 30,
          "internal_beta_group_ids" => []
        },
        "app_store" => {
          "enabled" => auto_create_store_version,
          "metadata_path" => metadata_path,
          "automatic_release" => true
        },
        "artifacts" => {
          "retention_days" => 30,
          "keep_xcarchive" => false
        }
      }
    end

    def dump_yaml(data)
      YAML.dump(data)
    end
  end
end
