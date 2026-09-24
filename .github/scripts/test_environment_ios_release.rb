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
    workflows = {
      ".github/workflows/photo-ios-ci.yml" => "39a136d4c560879ec35f3fd23c44f0b1eae4bc30",
      ".github/workflows/tripcost-ios-release.yml" => "6160d17ca99597c95b665823e5222de785348254",
      ".github/workflows/donesome-ios-release.yml" => "39a136d4c560879ec35f3fd23c44f0b1eae4bc30",
      ".github/workflows/sdpacket-ios-release.yml" => "6160d17ca99597c95b665823e5222de785348254",
      ".github/workflows/plotproof-lab-ios-release.yml" => "6160d17ca99597c95b665823e5222de785348254"
    }
    workflows.each do |path, expected_pin|
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
      assert_includes text, "update_asc_text_metadata: ${{ inputs.update_asc_text_metadata }}"
      assert_includes text, "replace_asc_media: ${{ inputs.replace_asc_media }}"
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

  def test_p8_normalization_accepts_raw_or_base64_key
    key = OpenSSL::PKey::EC.generate("prime256v1")
    pem = key.to_pem

    raw = Release.normalize_p8(pem)
    encoded = Release.normalize_p8([pem].pack("m0"))

    assert_equal raw, encoded
    assert_equal pem, raw.unpack1("m0")
  end
end
