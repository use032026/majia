# frozen_string_literal: true

require_relative "asc_approved_version_release"

module MajiaCI
  module DeynuApprovedRelease
    module_function

    BUNDLE_ID = "com.almanac.lite"
    APP_ID = "6824457290"
    VERSION = "1.0.2"
    VERSION_ID = "676b323f-1a54-4d86-b8e0-0b79baaf340c"
    BUILD_ID = "35351e2e-1b0c-45bd-a0d4-ba087083deed"
    BUILD_NUMBER = "1"
    READY_STATES = ASCApprovedVersionRelease::READY_STATES
    VERSION_PATH = "/v1/appStoreVersions/#{VERSION_ID}"
    TARGET = ASCApprovedVersionRelease.new(
      bundle_id: BUNDLE_ID, app_id: APP_ID, version: VERSION, version_id: VERSION_ID,
      build_id: BUILD_ID, build_number: BUILD_NUMBER
    ).freeze

    def base_summary(**options)
      TARGET.base_summary(**options)
    end

    def release(**options)
      TARGET.release(**options)
    end
  end
end
