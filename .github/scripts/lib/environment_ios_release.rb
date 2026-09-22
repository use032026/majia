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

    def validate_release_switches!(upload_to_asc:, auto_create_store_version:)
      if auto_create_store_version && !upload_to_asc
        raise ReleaseInputError, "auto_create_store_version=true requires upload_to_asc=true"
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

    def build_metadata(release_notes_json:, enabled:)
      return {} unless enabled

      release_notes = JSON.parse(release_notes_json)
      unless release_notes.is_a?(Hash) && !release_notes.empty?
        raise ReleaseInputError,
              "release_notes_json must map every ASC locale to non-empty release notes"
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

      {
        "uses_non_exempt_encryption" => false,
        "localizations" => localizations
      }
    rescue JSON::ParserError => e
      raise ReleaseInputError, "release_notes_json is invalid JSON: #{e.message}"
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
