# frozen_string_literal: true

require "minitest/autorun"
require "openssl"
require "yaml"
require_relative "lib/environment_ios_release"

class EnvironmentIOSReleaseTest < Minitest::Test
  Release = MajiaCI::EnvironmentIOSRelease

  def test_store_version_switch_requires_upload
    error = assert_raises(MajiaCI::ReleaseInputError) do
      Release.validate_release_switches!(
        upload_to_asc: false,
        auto_create_store_version: true,
        submit: false,
        update_asc_text_metadata: false,
        replace_asc_media: false
      )
    end
    assert_includes error.message, "requires upload_to_asc=true"
  end

  def test_submit_switch_requires_store_version_automation
    error = assert_raises(MajiaCI::ReleaseInputError) do
      Release.validate_release_switches!(
        upload_to_asc: true,
        auto_create_store_version: false,
        submit: true,
        update_asc_text_metadata: false,
        replace_asc_media: false
      )
    end
    assert_includes error.message, "submit=true requires auto_create_store_version=true"
  end

  def test_store_version_creation_can_run_with_or_without_submission
    [false, true].each do |submit|
      assert_nil Release.validate_release_switches!(
        upload_to_asc: true,
        auto_create_store_version: true,
        submit: submit,
        update_asc_text_metadata: false,
        replace_asc_media: false
      )
    end
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
    assert Release.whats_new_changes?(metadata)
    external_metadata = Release.without_whats_new(metadata)
    assert_nil external_metadata["localizations"]
    refute Release.text_metadata_changes?(external_metadata)
    mixed_metadata = Release.without_whats_new(
      "localizations" => {
        "en-US" => { "whats_new" => "Bug fixes.", "description" => "Kept description" }
      }
    )
    assert_equal "Kept description", mixed_metadata.dig("localizations", "en-US", "description")
    assert Release.text_metadata_changes?(mixed_metadata)
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
        submit: false,
        update_asc_text_metadata: true,
        replace_asc_media: false
      )
    end
    assert_includes error.message, "requires auto_create_store_version=true"

    error = assert_raises(MajiaCI::ReleaseInputError) do
      Release.validate_release_switches!(
        upload_to_asc: true,
        auto_create_store_version: false,
        submit: false,
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

  def test_config_enables_store_version_preparation
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

  def test_all_release_workflows_expose_independent_release_switches_and_pin_expected_action_commits
    expected_pin = "b2a2e38df4eac58c35d1bf8b5dc7cc987be467d9"
    workflows = %w[
      .github/workflows/photo-ios-ci.yml
      .github/workflows/tripcost-ios-release.yml
      .github/workflows/donesome-ios-release.yml
      .github/workflows/sdpacket-ios-release.yml
      .github/workflows/plotproof-lab-ios-release.yml
    ]
    workflows.each do |path|
      text = File.read(path, encoding: "UTF-8")
      assert_includes text, "submit:"
      assert_includes text, "description: Submit the created or reused store version to App Review after processing"
      assert_includes text, "--submit \"$SUBMIT\""
      assert_includes text, "update_asc_text_metadata:"
      assert_includes text, "replace_asc_media:"
      assert_includes text, 'submit_to_review: "false"'
      refute_includes text, "submit_to_review: ${{ inputs.auto_create_store_version }}"
      refute_includes text, "submit_to_review: ${{ inputs.submit }}"
      assert_includes text, "if: ${{ inputs.submit }}"
      assert_includes text, "ruby .github/scripts/submit-asc-review.rb"
      assert_includes text, "update_asc_text_metadata: ${{ steps.prepare.outputs.external_update_text_metadata }}"
      assert_includes text, "replace_asc_media: ${{ inputs.replace_asc_media }}"
      assert_includes text, "if: ${{ steps.prepare.outputs.sync_whats_new == 'true' }}"
      assert_includes text, "ruby .github/scripts/sync-asc-whats-new.rb"
      assert_includes text, "Retain What's New evidence"
      assert_includes text, "REQUESTED_SUBMIT: ${{ inputs.submit }}"
      assert_includes text, 'echo "- Store version create/reuse requested: ${REQUESTED_STORE_VERSION}"'
      assert_includes text, 'echo "- Review submission requested: ${REQUESTED_SUBMIT}"'
      pin = text[/CherryIce\/ios-multi-app-cloud-build-system\/.github\/actions\/build-upload@([0-9a-f]{40})/, 1]
      assert_equal expected_pin, pin
    end
  end

  def test_plotproof_lab_workflow_uses_its_environment_and_nested_monorepo_paths
    text = File.read(".github/workflows/plotproof-lab-ios-release.yml", encoding: "UTF-8")

    assert_includes text, "environment: plotproof_lab-production"
    assert_includes text, "--app-key plotproof-lab"
    assert_includes text, '--app-name "PlotProof Lab"'
    assert_includes text, "--project-directory apps/plotproof_lab/plotproof_lab"
    assert_includes text, "--container-path apps/plotproof_lab/plotproof_lab/ios/Runner.xcworkspace"
    assert_includes text, "--targets-json '[{\"suffix\":\"\",\"target\":\"Runner\",\"profile_alias\":\"app\"}]'"
    assert_includes text, "--metadata-template apps/plotproof_lab/plotproof_lab/app-store/metadata.yml"
    assert_includes text, "PLOTPROOF_BUNDLE_ID = %s"
    assert_includes text, 'XCODE_XCCONFIG_FILE=${identity_config}'

    project = File.read(
      "apps/plotproof_lab/plotproof_lab/ios/Runner.xcodeproj/project.pbxproj",
      encoding: "UTF-8"
    )
    assert_equal 3, project.scan("PLOTPROOF_BUNDLE_ID = com.example.plotproofLab;").length
    assert_equal 3, project.scan('PRODUCT_BUNDLE_IDENTIFIER = "$(PLOTPROOF_BUNDLE_ID)";').length
  end

  def test_sdpacket_workflow_uses_its_environment_and_monorepo_paths
    text = File.read(".github/workflows/sdpacket-ios-release.yml", encoding: "UTF-8")

    assert_includes text, "environment: sdpacket-production"
    assert_includes text, "--app-key sdpacket"
    assert_includes text, "--app-name KIFXPRO"
    assert_includes text, "--project-directory apps/sdpacket"
    assert_includes text, "--container-path apps/sdpacket/ios/Runner.xcworkspace"
    assert_includes text, "--targets-json '[{\"suffix\":\"\",\"target\":\"Runner\",\"profile_alias\":\"app\"}]'"
    assert_includes text, "--metadata-template apps/sdpacket/app-store/metadata.yml"
  end

  def test_p8_normalization_accepts_common_secret_representations
    key = OpenSSL::PKey::EC.generate("prime256v1")
    pem = key.to_pem

    raw = Release.normalize_p8(pem)
    encoded = Release.normalize_p8([pem].pack("m0"))
    escaped_lf = Release.normalize_p8(pem.gsub("\n", "\\n"))
    escaped_crlf = Release.normalize_p8(pem.gsub("\n", "\\r\\n"))
    json_string = Release.normalize_p8(pem.to_json)
    assignment = Release.normalize_p8("ASC_API_KEY_P8=#{pem}")
    double_encoded = Release.normalize_p8([[pem].pack("m0")].pack("m0"))
    collapsed = Release.normalize_p8(pem.lines.map(&:strip).join(" "))

    assert_equal raw, encoded
    assert_equal raw, escaped_lf
    assert_equal raw, escaped_crlf
    assert_equal raw, json_string
    assert_equal raw, assignment
    assert_equal raw, double_encoded
    assert_equal raw, collapsed
    assert_equal pem, raw.unpack1("m0")
  end

  def test_generic_existing_build_release_supports_every_app_without_uploading_a_new_binary
    text = File.read(".github/workflows/asc-existing-build-release.yml", encoding: "UTF-8")

    %w[
      photo-production hearthio-production tripcost-production sdpacket-production
      plotproof_lab-production
    ].each { |environment| assert_includes text, "- #{environment}" }
    assert_includes text, "environment: ${{ inputs.app_environment }}"
    assert_includes text, "marketing_version:"
    assert_includes text, "build_number:"
    assert_includes text, "release_notes_json:"
    assert_includes text, "b2a2e38df4eac58c35d1bf8b5dc7cc987be467d9"
    assert_includes text, '--app-environment "$APP_ENVIRONMENT"'
    assert_includes text, "scripts/wait-asc.rb"
    assert_includes text, "--wait-level processing_complete"
    assert_includes text, "scripts/release-app-store.rb"
    assert_includes text, "--phase finalize"
    assert_includes text, "--submit-to-review false"
    assert_includes text, "--update-text-metadata false"
    assert_includes text, "ruby .github/scripts/sync-asc-whats-new.rb"
    assert_includes text, "asc-existing-build-whats-new.json"
    assert_includes text, "ruby .github/scripts/submit-asc-review.rb"
    assert_includes text, "New IPA upload performed: false"
    refute_includes text, "build-upload@"
    refute_includes text, "IOS_DISTRIBUTION_P12_BASE64"
    refute_includes text, "IOS_APPSTORE_PROFILE_BASE64"
    refute_includes text, "scripts/upload.sh"
  end

  def test_all_workflows_are_valid_yaml
    Dir.glob(".github/workflows/*.yml").each do |path|
      assert_kind_of Hash, YAML.safe_load(File.read(path, encoding: "UTF-8"), aliases: true), path
    end
  end
end
