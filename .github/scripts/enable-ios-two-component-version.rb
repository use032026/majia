#!/usr/bin/env ruby
# frozen_string_literal: true

# Adapt only Deynu's checked-out, pinned build engine. Other apps keep its original validation.
require "pathname"

engine = Pathname.new(ARGV.fetch(0)).realpath
preflight = engine.join("scripts/preflight.rb")
source = preflight.read
original = 'unless marketing_version.match?(/\A(?:0|[1-9]\d*)\.(?:0|[1-9]\d*)\.(?:0|[1-9]\d*)\z/)'
replacement = 'unless marketing_version.match?(/\A(?:0|[1-9]\d*)\.(?:0|[1-9]\d*)(?:\.(?:0|[1-9]\d*))?\z/)'
abort "Pinned iOS engine version validation changed; refusing to patch" unless source.scan(original).length == 1

preflight.write(source.sub(original, replacement).sub(
  "marketing version must contain three dot-separated non-negative integers",
  "marketing version must contain two or three dot-separated non-negative integers"
))
puts "Enabled two-component marketing versions in Deynu's pinned build engine copy"
