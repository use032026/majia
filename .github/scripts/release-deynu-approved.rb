#!/usr/bin/env ruby
# frozen_string_literal: true

require_relative "lib/deynu_approved_release"
require_relative "lib/asc_approved_release_cli"

target = MajiaCI::DeynuApprovedRelease
exit MajiaCI::ASCApprovedReleaseCLI.run(
  target: target, app_name: "Deynu", bundle_id: target::BUNDLE_ID,
  version: target::VERSION, argv: ARGV
)
