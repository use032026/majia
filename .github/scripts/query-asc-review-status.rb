#!/usr/bin/env ruby
# frozen_string_literal: true

require "json"
require "optparse"
require_relative "lib/asc_review_status"
require_relative "lib/asc_review_diagnostics"
require_relative "lib/asc_review_history"
require_relative "lib/asc_readonly_summary"

options = { marketing_version: "" }
OptionParser.new do |parser|
  parser.on("--bundle-id BUNDLE_ID") { |value| options[:bundle_id] = value }
  parser.on("--marketing-version VERSION") { |value| options[:marketing_version] = value }
  parser.on("--build-inventory") { options[:build_inventory] = true }
  parser.on("--review-diagnostics") { options[:review_diagnostics] = true }
  parser.on("--review-history") { options[:review_history] = true }
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
  if %i[review_diagnostics build_inventory review_history].count { |mode| options[mode] } > 1
    raise MajiaCI::ASCStatusError, "select one ASC query mode"
  end
  if options[:review_history] && !options.fetch(:marketing_version).empty?
    raise MajiaCI::ASCStatusError, "review history cannot be combined with a marketing version"
  end

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
  if options[:review_history]
    history = MajiaCI::ASCReviewHistory.read(client: client, bundle_id: options.fetch(:bundle_id))
    File.open(options.fetch(:output), "w", 0o600) { |file| file.puts(JSON.pretty_generate(history)) }
    File.open(options.fetch(:github_summary), "a", 0o600) do |file|
      file.write(MajiaCI::ASCReadonlySummary.markdown(:history, history))
    end
    puts "ASC review history queried"
    exit(history.fetch("api_scan_complete") ? 0 : 1)
  end
  if options[:review_diagnostics]
    diagnostic = MajiaCI::ASCReviewDiagnostics.read(
      client: client,
      bundle_id: options.fetch(:bundle_id),
      marketing_version: options.fetch(:marketing_version)
    )
    File.open(options.fetch(:output), "w", 0o600) do |file|
      file.puts(JSON.pretty_generate(diagnostic))
    end
    File.open(options.fetch(:github_summary), "a", 0o600) do |file|
      file.write(MajiaCI::ASCReadonlySummary.markdown(:diagnostics, diagnostic))
    end
    puts "ASC review diagnostics queried"
    exit(diagnostic.fetch("complete") ? 0 : 1)
  end

  if options[:build_inventory]
    inventory = MajiaCI::ASCReviewStatus.build_inventory(
      client: client,
      bundle_id: options.fetch(:bundle_id),
      marketing_version: options.fetch(:marketing_version)
    )
    File.open(options.fetch(:output), "w", 0o600) do |file|
      file.puts(JSON.pretty_generate(inventory))
    end
    File.open(options.fetch(:github_summary), "a", 0o600) do |file|
      file.write(MajiaCI::ASCReadonlySummary.markdown(:inventory, inventory))
    end
    puts "ASC build inventory queried"
    exit 0
  end

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
    file.write(MajiaCI::ASCReadonlySummary.markdown(:status, summary))
  end
  puts [
    "ASC review status queried",
    "app=#{summary.dig('app', 'name')}",
    "version=#{summary.dig('version', 'version_string')}",
    "app_version_state=#{summary.dig('version', 'app_version_state')}",
    "review_submission_state=#{summary.dig('review_submission', 'state') || 'not-found'}"
  ].join(" ")
rescue MajiaCI::ASCStatusError, KeyError, Errno::ENOENT, Errno::EACCES => e
  if options[:review_history]
    warn "ASC review history could not be completed"
  else
    warn(options[:review_diagnostics] ? "ASC review diagnostics could not be completed" : e.message)
  end
  exit 1
end
