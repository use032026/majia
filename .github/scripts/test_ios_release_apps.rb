# frozen_string_literal: true

require "minitest/autorun"
require "yaml"
require_relative "lib/ios_release_apps"

class IOSReleaseAppsTest < Minitest::Test
  Registry = MajiaCI::IOSReleaseApps

  def test_registry_covers_every_release_environment_and_existing_paths
    expected = %w[
      almanac-production cleantrail-production filepeek-production hearthio-production photo-production plotproof_lab-production
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
