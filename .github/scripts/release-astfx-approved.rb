#!/usr/bin/env ruby
# frozen_string_literal: true

require_relative "lib/astfx_approved_release"
require_relative "lib/asc_approved_release_cli"

target = MajiaCI::ASTFXApprovedRelease
exit MajiaCI::ASCApprovedReleaseCLI.run(
  target: target::TARGET, app_name: "ASTFX", bundle_id: target::BUNDLE_ID,
  version: target::VERSION, argv: ARGV
)
