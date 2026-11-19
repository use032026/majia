# frozen_string_literal: true

require "minitest/autorun"
require "yaml"
require_relative "lib/ios_release_apps"

class IOSReleaseAppsTest < Minitest::Test
  Registry = MajiaCI::IOSReleaseApps

  def test_registry_covers_every_release_environment_and_existing_paths
    expected = %w[
      almanac-production cleantrail-production filepeek-production hearthio-production photo-production photoreport-production plotproof_lab-production
      sdpacket-production steady-production
      tripcost-production tripdelta-production
    ]
    assert_equal expected, Registry::APPS.keys.sort

    Registry::APPS.each_value do |app|
      assert File.directory?(app.fetch("project_directory"))
      assert File.file?(app.fetch("metadata_template"))
      assert app.fetch("container_path").start_with?("#{app.fetch('project_directory')}/")
      refute_empty app.fetch("targets")
    end
  end

  def test_astfx_uses_the_protected_existing_build_route
    app = Registry.fetch("cleantrail-production")
    assert_equal "ASTFX", app.fetch("app_name")
    assert_equal "cleantrail", app.fetch("app_key")
    assert_equal "apps/cleantrail/cleantrail/ios/Runner.xcworkspace", app.fetch("container_path")
    assert_equal [{ "suffix" => "", "target" => "Runner", "profile_alias" => "app" }], app.fetch("targets")
    assert Registry.automatic_release_for("cleantrail")

    workflow = YAML.load_file(".github/workflows/asc-existing-build-release.yml")
    trigger = workflow.fetch(true) { workflow.fetch("on") }
    inputs = trigger.fetch("workflow_dispatch").fetch("inputs")
    assert_equal Registry::APPS.keys.sort, inputs.dig("app_environment", "options").sort
    assert_equal true, inputs.dig("marketing_version", "required")
    assert_equal true, inputs.dig("build_number", "required")
    assert_equal false, inputs.dig("submit", "default")
    assert_equal '${{ inputs.app_environment }}', workflow.dig("jobs", "store_release", "environment")
  end

  def test_tripcost_registry_keeps_the_widget_target
    app = Registry.fetch("tripcost-production")
    widget = app.fetch("targets").find { |target| target.fetch("suffix") == ".widget" }

    assert_equal "AppWidget", widget.fetch("target")
    assert_equal "widget", widget.fetch("profile_alias")
  end

  def test_photo_uses_the_current_asc_app_name
    assert_equal "Jufu", Registry.fetch("photo-production").fetch("app_name")
  end

  def test_jovfx_reuses_its_production_environment_and_manual_release_route
    app = Registry.fetch("photoreport-production")
    assert_equal "JOVFX", app.fetch("app_name")
    assert_equal "apps/photoreport", app.fetch("project_directory")
    assert_equal "apps/photoreport/ios/Runner.xcworkspace", app.fetch("container_path")
    assert Registry.automatic_release_for("photoreport")
    refute_equal Registry.fetch("photo-production"), app

    workflow = YAML.load_file(".github/workflows/photoreport-ios-release.yml")
    trigger = workflow.fetch(true) { workflow.fetch("on") }
    assert_equal ["workflow_dispatch"], trigger.keys
    inputs = trigger.fetch("workflow_dispatch").fetch("inputs")
    assert_equal "1.0.1", inputs.dig("marketing_version", "default")
    assert_equal false, inputs.dig("upload_to_asc", "default")
    assert_equal "read", workflow.dig("permissions", "contents")
    job = workflow.dig("jobs", "upload")
    assert_equal "photoreport-production", job.fetch("environment")
    assert_includes job.fetch("if"), "refs/heads/main"
    steps = job.fetch("steps")
    prepare = steps.find { |step| step["id"] == "prepare" }
    assert_includes prepare.fetch("run"), "com.jovfx.lite"
    action = steps.find { |step| step["id"] == "release" }
    assert_equal '${{ inputs.marketing_version }}', action.dig("with", "marketing_version")
    assert_equal '${{ inputs.build_number }}', action.dig("with", "build_number")
    assert_equal '${{ inputs.upload_to_asc }}', action.dig("with", "upload_to_asc")
    %w[submit_to_review update_asc_text_metadata replace_asc_media].each do |key|
      assert_equal "false", action.dig("with", key)
    end
    %w[asc-review-status.yml asc-existing-build-release.yml asc-submit-review.yml].each do |filename|
      route = YAML.load_file(".github/workflows/#{filename}")
      route_trigger = route.fetch(true) { route.fetch("on") }
      assert_includes route_trigger.dig("workflow_dispatch", "inputs", "app_environment", "options"), "photoreport-production"
    end
    lock = File.read("apps/photoreport/ios/Podfile.lock")
    assert_match(/^COCOAPODS: 1\.17\.0$/, lock)
    metadata = YAML.load_file(app.fetch("metadata_template"))
    assert_equal({ "uses_non_exempt_encryption" => false }, metadata)
  end

  def test_unknown_environment_is_rejected_with_the_requested_error_type
    error = assert_raises(ArgumentError) do
      Registry.fetch("unknown-production", error_class: ArgumentError)
    end
    assert_includes error.message, "unsupported app environment"
  end

  def test_deynu_uses_automatic_release_without_changing_other_apps
    assert_equal true, Registry.fetch("almanac-production").fetch("automatic_release")
    assert_equal true, Registry.automatic_release_for("almanac")
    Registry::APPS.each_value do |app|
      next if app.fetch("app_key") == "almanac"

      assert_equal true, Registry.automatic_release_for(app.fetch("app_key"))
      assert_equal true, app.fetch("automatic_release", true)
    end
    assert_equal true, Registry.automatic_release_for("cleantrail")
  end
end
