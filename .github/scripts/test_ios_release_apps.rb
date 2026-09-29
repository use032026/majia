# frozen_string_literal: true

require "minitest/autorun"
require_relative "lib/ios_release_apps"

class IOSReleaseAppsTest < Minitest::Test
  Registry = MajiaCI::IOSReleaseApps

  def test_registry_covers_every_release_environment_and_existing_paths
    expected = %w[
      hearthio-production photo-production plotproof_lab-production sdpacket-production
      tripcost-production
    ]
    assert_equal expected, Registry::APPS.keys.sort

    Registry::APPS.each_value do |app|
      assert File.directory?(app.fetch("project_directory"))
      assert File.file?(app.fetch("metadata_template"))
      assert app.fetch("container_path").start_with?("#{app.fetch('project_directory')}/")
      refute_empty app.fetch("targets")
    end
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
end
