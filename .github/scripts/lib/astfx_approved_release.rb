# frozen_string_literal: true

require_relative "asc_approved_version_release"

module MajiaCI
  module ASTFXApprovedRelease
    BUNDLE_ID = "com.astfx.lite"
    VERSION = "1.0.2"
    TARGET = ASCApprovedVersionRelease.new(
      bundle_id: BUNDLE_ID, app_id: "6827824646", version: VERSION,
      version_id: "d4bbfe6f-612a-42a6-a6dc-74781d92baca",
      build_id: "54710387-f2b5-4402-abc0-56969afeccd5", build_number: "1"
    ).freeze
  end
end
