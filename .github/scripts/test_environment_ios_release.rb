# frozen_string_literal: true

require "minitest/autorun"
require "openssl"
require_relative "lib/environment_ios_release"

class EnvironmentIOSReleaseTest < Minitest::Test
  Release = MajiaCI::EnvironmentIOSRelease

  def test_store_version_switch_requires_upload
    error = assert_raises(MajiaCI::ReleaseInputError) do
      Release.validate_release_switches!(
        upload_to_asc: false,
        auto_create_store_version: true,
        update_asc_text_metadata: false,
        replace_asc_media: false
      )
    end
    assert_includes error.message, "requires upload_to_asc=true"
  end

  def test_metadata_merges_only_explicit_release_notes_into_the_template
    template = File.join(Dir.pwd, "apps/tripcost/app-store/metadata.yml")
    metadata = Release.build_metadata(
      template_path: template,
      release_notes_json: '{"en-US":"Bug fixes.","zh-Hans":"问题修复。"}',
      update_text_metadata: true
    )

    assert_equal false, metadata["uses_non_exempt_encryption"]
    assert_equal "Bug fixes.", metadata.dig("localizations", "en-US", "whats_new")
    assert_equal "问题修复。", metadata.dig("localizations", "zh-Hans", "whats_new")
    untouched = Release.build_metadata(
      template_path: template,
      release_notes_json: "{}",
      update_text_metadata: false
    )
    assert_nil untouched["localizations"]
  end

  def test_metadata_switches_require_store_version_automation
    error = assert_raises(MajiaCI::ReleaseInputError) do
      Release.validate_release_switches!(
        upload_to_asc: true,
        auto_create_store_version: false,
        update_asc_text_metadata: true,
        replace_asc_media: false
      )
    end
    assert_includes error.message, "requires auto_create_store_version=true"

    error = assert_raises(MajiaCI::ReleaseInputError) do
      Release.validate_release_switches!(
        upload_to_asc: true,
        auto_create_store_version: false,
        update_asc_text_metadata: false,
        replace_asc_media: true
      )
    end
    assert_includes error.message, "requires auto_create_store_version=true"
  end

  def test_release_notes_are_rejected_when_text_update_is_off
    template = File.join(Dir.pwd, "apps/tripcost/app-store/metadata.yml")
    error = assert_raises(MajiaCI::ReleaseInputError) do
      Release.build_metadata(
        template_path: template,
        release_notes_json: '{"en-US":"Bug fixes."}',
        update_text_metadata: false
      )
    end
    assert_includes error.message, "requires update_asc_text_metadata=true"
  end

  def test_config_ties_store_preparation_to_automatic_release
    config = Release.build_config(
      app_name: "RoamSum",
      team_id: "ABCDE12345",
      bundle_id: "com.example.roamsum",
      scheme: "Runner",
      project_directory: "apps/tripcost",
      container_path: "apps/tripcost/ios/Runner.xcworkspace",
      targets: Release.parse_targets(
        '[{"suffix":"","target":"Runner","profile_alias":"app"},' \
        '{"suffix":".widget","target":"AppWidget","profile_alias":"widget"}]'
      ),
      upload_to_asc: true,
      auto_create_store_version: true,
      metadata_path: ".github/runtime-tripcost-app-store-metadata.yml"
    )

    assert_equal "asc_increment", config.dig("versioning", "build_number_strategy")
    assert_equal true, config.dig("app_store", "enabled")
    assert_equal true, config.dig("app_store", "automatic_release")
    assert_equal "processing_complete", config.dig("upload", "wait_level")
    assert_equal "com.example.roamsum.widget", config.dig("app", "bundle_ids", 1, "bundle_id")
  end

  def test_all_three_workflows_expose_independent_metadata_switches_and_pin_one_action_commit
    workflows = %w[
      .github/workflows/photo-ios-ci.yml
      .github/workflows/tripcost-ios-release.yml
      .github/workflows/donesome-ios-release.yml
    ]
    pins = workflows.map do |path|
      text = File.read(path, encoding: "UTF-8")
      assert_includes text, "update_asc_text_metadata:"
      assert_includes text, "replace_asc_media:"
      assert_includes text, "submit_to_review: ${{ inputs.auto_create_store_version }}"
      assert_includes text, "update_asc_text_metadata: ${{ inputs.update_asc_text_metadata }}"
      assert_includes text, "replace_asc_media: ${{ inputs.replace_asc_media }}"
      text[/CherryIce\/ios-multi-app-cloud-build-system\/.github\/actions\/build-upload@([0-9a-f]{40})/, 1]
    end

    refute_includes pins, nil
    assert_equal 1, pins.uniq.length
  end

  def test_p8_normalization_accepts_raw_or_base64_key
    key = OpenSSL::PKey::EC.generate("prime256v1")
    pem = key.to_pem

    raw = Release.normalize_p8(pem)
    encoded = Release.normalize_p8([pem].pack("m0"))

    assert_equal raw, encoded
    assert_equal pem, raw.unpack1("m0")
  end
end
