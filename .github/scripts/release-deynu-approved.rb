#!/usr/bin/env ruby
# frozen_string_literal: true

require "json"
require "optparse"
require_relative "lib/deynu_approved_release"

def write_release_evidence(path, summary)
  File.open(path, File::WRONLY | File::CREAT | File::TRUNC, 0o600) do |file|
    file.write(JSON.pretty_generate(summary))
    file.write("\n")
    file.flush
    file.fsync
  end
end

options = { execute: false }
summary = MajiaCI::DeynuApprovedRelease.base_summary
begin
  OptionParser.new do |parser|
    parser.on("--execute") { options[:execute] = true }
    parser.on("--output PATH") { |value| options[:output] = value }
    parser.on("--github-output PATH") { |value| options[:github_output] = value }
    parser.on("--github-summary PATH") { |value| options[:github_summary] = value }
  end.parse!
  raise ArgumentError, "unexpected arguments" unless ARGV.empty?
  raise ArgumentError, "output required" if options[:output].to_s.empty?

  summary = MajiaCI::DeynuApprovedRelease.base_summary(execute: options[:execute])
  # Produce a redacted file even when authentication/configuration fails.
  write_release_evidence(options.fetch(:output), summary)
  bundle = ENV.fetch("IOS_BUNDLE_ID", "")
  raise ArgumentError, "wrong bundle" unless bundle == MajiaCI::DeynuApprovedRelease::BUNDLE_ID

  key_id = ENV.fetch("ASC_KEY_ID", "")
  issuer_id = ENV.fetch("ASC_ISSUER_ID", "")
  MajiaCI::ASCReviewStatus.validate_inputs!(
    bundle_id: bundle, marketing_version: MajiaCI::DeynuApprovedRelease::VERSION,
    key_id: key_id, issuer_id: issuer_id
  )
  key = MajiaCI::ASCReviewStatus.normalize_private_key(ENV.fetch("ASC_API_KEY_P8", ""))
  client = MajiaCI::ASCClient.new(key: key, key_id: key_id, issuer_id: issuer_id)
  summary = MajiaCI::DeynuApprovedRelease.release(
    client: client, execute: options[:execute], run_attempt: ENV.fetch("GITHUB_RUN_ATTEMPT", "1"),
    checkpoint: ->(value) { write_release_evidence(options.fetch(:output), value) }
  )
rescue StandardError
  summary["error_code"] = "invalid_configuration_or_evidence_io"
ensure
  if options[:output] && !options[:output].empty?
    begin
      write_release_evidence(options[:output], summary)
    rescue StandardError
      summary["error_code"] = "evidence_write_failed"
    end
  end
end

begin
  if options[:github_output]
    File.open(options[:github_output], "a", 0o600) do |output|
      %w[post_attempted request_accepted release_request_id distribution_ready no_op no_op_reason error_code post_http_status].each do |field|
        output.puts "#{field}=#{summary[field]}"
      end
    end
  end
  if options[:github_summary]
    File.open(options[:github_summary], "a", 0o600) do |output|
      output.puts "## Deynu approved 1.0.2 release"
      %w[post_attempted request_accepted release_request_id distribution_ready no_op no_op_reason error_code post_http_status].each do |field|
        output.puts "- #{field}: #{summary[field]}"
      end
      output.puts "\n#{summary.fetch('evidence_boundary')}"
    end
  end
rescue StandardError
  warn "Deynu release summary output failed; inspect JSON evidence before any further action."
  exit 1
end
puts "Deynu 1.0.2 release request_accepted=#{summary['request_accepted']} distribution_ready=#{summary['distribution_ready']} error_code=#{summary['error_code'] || 'none'}"
exit(summary["error_code"] ? 1 : 0)
