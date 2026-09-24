#!/usr/bin/env ruby
# frozen_string_literal: true

require "json"
require "optparse"
require_relative "lib/asc_review_status"

options = { marketing_version: "" }
OptionParser.new do |parser|
  parser.on("--bundle-id BUNDLE_ID") { |value| options[:bundle_id] = value }
  parser.on("--marketing-version VERSION") { |value| options[:marketing_version] = value }
  parser.on("--output PATH") { |value| options[:output] = value }
  parser.on("--github-summary PATH") { |value| options[:github_summary] = value }
end.parse!

def required_environment(name)
  value = ENV.fetch(name, "")
  raise MajiaCI::ASCStatusError, "#{name} is required" if value.empty?

  value
end

begin
  required = %i[bundle_id output github_summary]
  missing = required.reject { |key| options[key] && !options[key].empty? }
  raise MajiaCI::ASCStatusError, "missing options: #{missing.join(', ')}" unless missing.empty?

  key_id = required_environment("ASC_KEY_ID")
  issuer_id = required_environment("ASC_ISSUER_ID")
  MajiaCI::ASCReviewStatus.validate_inputs!(
    bundle_id: options.fetch(:bundle_id),
    marketing_version: options.fetch(:marketing_version),
    key_id: key_id,
    issuer_id: issuer_id
  )
  key = MajiaCI::ASCReviewStatus.normalize_private_key(required_environment("ASC_API_KEY_P8"))
  client = MajiaCI::ASCReadClient.new(key: key, key_id: key_id, issuer_id: issuer_id)
  summary = MajiaCI::ASCReviewStatus.build_status(
    client: client,
    bundle_id: options.fetch(:bundle_id),
    marketing_version: options.fetch(:marketing_version)
  )

  File.open(options.fetch(:output), "w", 0o600) do |file|
    file.write(JSON.pretty_generate(summary))
    file.write("\n")
  end
  File.open(options.fetch(:github_summary), "a", 0o600) do |file|
    file.write(MajiaCI::ASCReviewStatus.markdown(summary))
  end
  puts [
    "ASC review status queried",
    "app=#{summary.dig('app', 'name')}",
    "version=#{summary.dig('version', 'version_string')}",
    "app_version_state=#{summary.dig('version', 'app_version_state')}",
    "review_submission_state=#{summary.dig('review_submission', 'state') || 'not-found'}"
  ].join(" ")
rescue MajiaCI::ASCStatusError, KeyError, Errno::ENOENT, Errno::EACCES => e
  warn e.message
  exit 1
end
