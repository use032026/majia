# frozen_string_literal: true

require "json"

module MajiaCI
  module IOSReleaseApps
    module_function

    APPS = {
      "photo-production" => {
        "app_key" => "photo",
        "app_name" => "Jufu",
        "project_directory" => "apps/photo",
        "container_path" => "apps/photo/ios/Runner.xcworkspace",
        "targets" => [{ "suffix" => "", "target" => "Runner", "profile_alias" => "app" }],
        "metadata_template" => "apps/photo/app-store/metadata.yml"
      },
      "hearthio-production" => {
        "app_key" => "hearthio",
        "app_name" => "LAURUS",
        "project_directory" => "apps/donesome/Hearthio",
        "container_path" => "apps/donesome/Hearthio/ios/Runner.xcworkspace",
        "targets" => [{ "suffix" => "", "target" => "Runner", "profile_alias" => "app" }],
        "metadata_template" => "apps/donesome/Hearthio/app-store/metadata.yml"
      },
      "tripcost-production" => {
        "app_key" => "tripcost",
        "app_name" => "RoamSum",
        "project_directory" => "apps/tripcost",
        "container_path" => "apps/tripcost/ios/Runner.xcworkspace",
        "targets" => [
          { "suffix" => "", "target" => "Runner", "profile_alias" => "app" },
          { "suffix" => ".widget", "target" => "AppWidget", "profile_alias" => "widget" }
        ],
        "metadata_template" => "apps/tripcost/app-store/metadata.yml"
      },
      "sdpacket-production" => {
        "app_key" => "sdpacket",
        "app_name" => "KIFXPRO",
        "project_directory" => "apps/sdpacket",
        "container_path" => "apps/sdpacket/ios/Runner.xcworkspace",
        "targets" => [{ "suffix" => "", "target" => "Runner", "profile_alias" => "app" }],
        "metadata_template" => "apps/sdpacket/app-store/metadata.yml"
      },
      "plotproof_lab-production" => {
        "app_key" => "plotproof-lab",
        "app_name" => "PlotProof Lab",
        "project_directory" => "apps/plotproof_lab/plotproof_lab",
        "container_path" => "apps/plotproof_lab/plotproof_lab/ios/Runner.xcworkspace",
        "targets" => [{ "suffix" => "", "target" => "Runner", "profile_alias" => "app" }],
        "metadata_template" => "apps/plotproof_lab/plotproof_lab/app-store/metadata.yml"
      }
    }.freeze

    def fetch(environment, error_class: KeyError)
      APPS.fetch(environment) do
        raise error_class, "unsupported app environment #{environment.inspect}"
      end
    end

    def targets_json(app)
      JSON.generate(app.fetch("targets"))
    end
  end
end
