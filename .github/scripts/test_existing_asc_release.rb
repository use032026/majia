# frozen_string_literal: true

require "fileutils"
require "json"
require "minitest/autorun"
require "open3"
require "openssl"
require "rbconfig"
require "tmpdir"
require "yaml"

class ExistingASCReleaseTest < Minitest::Test
  CLI = File.expand_path("prepare-existing-asc-release.rb", __dir__)
  NOTES = { "en-US" => "Improved log validation efficiency." }.freeze

  def setup
    @root = File.realpath(Dir.mktmpdir("existing-asc-release-test-"))
    @workspace = File.join(@root, "workspace")
    @runner_temp = File.join(@root, "runner-temp")
    FileUtils.mkdir_p([@workspace, @runner_temp])
    @template = File.join(@workspace, "apps/filepeek/app-store/metadata.yml")
    FileUtils.mkdir_p(File.dirname(@template))
    @github_output = File.join(@root, "github-output")
    # Generated only for this offline CLI fixture; no account key or network is used.
    @private_key = OpenSSL::PKey::EC.generate("prime256v1").to_pem
    @env = {
      "GITHUB_WORKSPACE" => @workspace,
      "RUNNER_TEMP" => @runner_temp,
      "APPLE_TEAM_ID" => "ABCDE12345",
      "IOS_BUNDLE_ID" => "com.example.fixture",
      "IOS_SCHEME" => "Runner",
      "ASC_KEY_ID" => "ABCDE12345",
      "ASC_ISSUER_ID" => "12345678-1234-1234-1234-123456789abc",
      "ASC_API_KEY_P8" => @private_key
    }
  end

  def teardown
    FileUtils.remove_entry(@root)
  end

  def test_notes_only_requested_text_uses_independent_notes_sync
    run_cli(notes: NOTES, requested: "true")
    assert_prepared(external: false, notes: true)
    assert_equal({ "uses_non_exempt_encryption" => false }, metadata)
  end

  def test_empty_requested_text_fails_before_writing_release_inputs
    _stdout, stderr, status = run_cli(requested: "true", success: false)
    refute status.success?
    assert_includes stderr, "requires release notes or a declared text metadata change"
    refute File.exist?(@github_output)
    refute File.exist?(config_path)
    refute File.exist?(metadata_path)
    refute File.exist?(key_path)
  end

  def test_declared_other_text_requested_true_enables_external_update
    template = {
      "uses_non_exempt_encryption" => false,
      "localizations" => { "en-US" => { "description" => "Existing description." } },
      "review_detail" => { "notes" => "Existing review instructions." }
    }
    run_cli(template: template, requested: "true")
    assert_prepared(external: true, notes: false)
    assert_equal template, metadata
  end

  def test_mixed_text_and_notes_strips_only_whats_new_from_external_metadata
    template = {
      "uses_non_exempt_encryption" => false,
      "localizations" => { "en-US" => { "description" => "Keep description." } }
    }
    run_cli(template: template, notes: NOTES, requested: "true")
    assert_prepared(external: true, notes: true)
    assert_equal template, metadata
    refute metadata.fetch("localizations").fetch("en-US").key?("whats_new")
  end

  def test_false_keeps_notes_sync_and_preserves_other_metadata_without_enabling_it
    template = {
      "uses_non_exempt_encryption" => false,
      "copyright" => "Existing copyright",
      "localizations" => { "en-US" => { "description" => "Keep description." } }
    }
    run_cli(template: template, notes: NOTES, requested: "false")
    assert_prepared(external: false, notes: true)
    assert_equal template, metadata
  end

  def test_omitted_option_defaults_false_and_retains_existing_notes_behavior
    run_cli(notes: NOTES)
    assert_prepared(external: false, notes: true)
    assert_equal({ "uses_non_exempt_encryption" => false }, metadata)
  end

  def test_false_without_notes_prepares_encryption_only_metadata
    run_cli(requested: "false")
    assert_prepared(external: false, notes: false)
    assert_equal({ "uses_non_exempt_encryption" => false }, metadata)
  end

  def test_invalid_boolean_is_rejected_without_outputs
    _stdout, stderr, status = run_cli(requested: "yes", success: false)
    refute status.success?
    assert_includes stderr, "update_asc_text_metadata must be true or false"
    refute File.exist?(@github_output)
    refute File.exist?(config_path)
  end

  def test_workflow_passes_effective_text_flag_and_keeps_notes_sync_independent
    path = File.expand_path("../workflows/asc-existing-build-release.yml", __dir__)
    workflow = YAML.safe_load_file(path)
    steps = workflow.fetch("jobs").fetch("store_release").fetch("steps")
    by_id = steps.select { |step| step.key?("id") }.to_h { |step| [step.fetch("id"), step] }
    prepare = by_id.fetch("prepare")
    assert_equal "${{ inputs.update_asc_text_metadata }}", prepare.fetch("env").fetch("UPDATE_ASC_TEXT_METADATA")
    assert_includes prepare.fetch("run"), '--update-asc-text-metadata "$UPDATE_ASC_TEXT_METADATA"'

    metadata_step = by_id.fetch("store_metadata")
    assert_equal "${{ steps.prepare.outputs.external_update_text_metadata == 'true' || inputs.replace_asc_media }}",
                 metadata_step.fetch("if")
    assert_equal "${{ steps.prepare.outputs.external_update_text_metadata }}",
                 metadata_step.fetch("env").fetch("UPDATE_ASC_TEXT_METADATA")
    assert_includes metadata_step.fetch("run"), '--update-text-metadata "$UPDATE_ASC_TEXT_METADATA"'
    refute_includes metadata_step.to_yaml, "inputs.update_asc_text_metadata"

    notes_step = by_id.fetch("whats_new")
    assert_equal "${{ steps.prepare.outputs.sync_whats_new == 'true' }}", notes_step.fetch("if")
    assert_equal "${{ inputs.release_notes_json }}", notes_step.fetch("env").fetch("RELEASE_NOTES_JSON")
    assert_includes notes_step.fetch("run"), '--release-notes-json "$RELEASE_NOTES_JSON"'
    refute_includes notes_step.to_yaml, "external_update_text_metadata"
  end

  private

  def run_cli(template: { "uses_non_exempt_encryption" => false }, notes: {}, requested: nil, success: true)
    File.write(@template, YAML.dump(template))
    args = [
      RbConfig.ruby, CLI,
      "--app-environment", "filepeek-production",
      "--marketing-version", "1.0.7",
      "--release-notes-json", JSON.generate(notes),
      "--config-output", "existing-build-config.yml",
      "--metadata-output", ".github/runtime-existing-build-metadata.yml",
      "--key-output", "AuthKey_existing_build.p8",
      "--github-output", @github_output
    ]
    args.concat(["--update-asc-text-metadata", requested]) unless requested.nil?
    result = Open3.capture3(@env, *args, chdir: @workspace, unsetenv_others: true)
    assert result[2].success?, result[1] if success
    result
  end

  def assert_prepared(external:, notes:)
    outputs = File.readlines(@github_output, chomp: true).to_h { |line| line.split("=", 2) }
    assert_equal external.to_s, outputs.fetch("external_update_text_metadata")
    assert_equal notes.to_s, outputs.fetch("sync_whats_new")
    assert_equal "filepeek", outputs.fetch("app_key")
    assert_equal "Fylto", outputs.fetch("app_name")
    assert_equal config_path, outputs.fetch("config_path")
    assert_equal metadata_path, outputs.fetch("metadata_path")
    assert_equal key_path, outputs.fetch("key_path")
    assert_equal @private_key, File.read(key_path)
    [config_path, metadata_path, key_path].each do |path|
      assert_equal 0o600, File.stat(path).mode & 0o777
    end
    config = YAML.safe_load_file(config_path)
    assert_equal 2, config.fetch("schema_version")
    assert_equal ["workflow_dispatch"], config.dig("release", "allowed_events")
    assert_equal ["refs/heads/main"], config.dig("release", "allowed_ref_patterns")
    assert_equal "com.example.fixture", config.dig("app", "primary_bundle_id")
    assert_equal "Runner", config.dig("build", "scheme")
    assert_equal "apps/filepeek", config.dig("flutter", "project_directory")
    assert_equal "processing_complete", config.dig("upload", "wait_level")
    assert_equal true, config.dig("app_store", "enabled")
    assert_equal true, config.dig("app_store", "automatic_release")
    assert_equal ".github/runtime-existing-build-metadata.yml", config.dig("app_store", "metadata_path")
  end

  def metadata
    YAML.safe_load_file(metadata_path)
  end

  def config_path
    File.join(@runner_temp, "existing-build-config.yml")
  end

  def metadata_path
    File.join(@workspace, ".github/runtime-existing-build-metadata.yml")
  end

  def key_path
    File.join(@runner_temp, "AuthKey_existing_build.p8")
  end
end
