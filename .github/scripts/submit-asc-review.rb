#!/usr/bin/env ruby
# frozen_string_literal: true

require "json"
require "optparse"
require "time"
require_relative "lib/asc_review_submission"

options = {}
OptionParser.new do |parser|
  parser.on("--bundle-id BUNDLE_ID") { |value| options[:bundle_id] = value }
  parser.on("--marketing-version VERSION") { |value| options[:marketing_version] = value }
  parser.on("--output PATH") { |value| options[:output] = value }
  parser.on("--github-output PATH") { |value| options[:github_output] = value }
  parser.on("--github-summary PATH") { |value| options[:github_summary] = value }
end.parse!

def required_environment(name)
  value = ENV.fetch(name, "")
  raise MajiaCI::ASCStatusError, "#{name} is required" if value.empty?

  value
end

def write_json(path, value)
  File.open(path, "w", 0o600) do |file|
    file.write(JSON.pretty_generate(value))
    file.write("\n")
  end
end

begin
  required = %i[bundle_id marketing_version output github_output github_summary]
  missing = required.reject { |key| options[key] && !options[key].empty? }
  raise MajiaCI::ASCSubmissionError, "missing options: #{missing.join(', ')}" unless missing.empty?

  key_id = required_environment("ASC_KEY_ID")
  issuer_id = required_environment("ASC_ISSUER_ID")
  MajiaCI::ASCReviewStatus.validate_inputs!(
    bundle_id: options.fetch(:bundle_id),
    marketing_version: options.fetch(:marketing_version),
    key_id: key_id,
    issuer_id: issuer_id
  )
  key = MajiaCI::ASCReviewStatus.normalize_private_key(required_environment("ASC_API_KEY_P8"))
  client = MajiaCI::ASCClient.new(key: key, key_id: key_id, issuer_id: issuer_id)
  summary = MajiaCI::ASCReviewSubmission.submit(
    client: client,
    bundle_id: options.fetch(:bundle_id),
    marketing_version: options.fetch(:marketing_version)
  )

  write_json(options.fetch(:output), summary)
  File.open(options.fetch(:github_summary), "a", 0o600) do |file|
    file.write(MajiaCI::ASCReviewSubmission.markdown(summary))
  end
  File.open(options.fetch(:github_output), "a", 0o600) do |output|
    output.puts "review_submission_id=#{summary.dig('review_submission', 'id')}"
    output.puts "review_submission_state=#{summary.dig('review_submission', 'state')}"
    output.puts "review_submitted=#{summary.fetch('review_submitted')}"
    output.puts "submission_no_op=#{summary.fetch('no_op')}"
    output.puts "submission_no_op_reason=#{summary['no_op_reason']}"
  end
  puts [
    "ASC review submission",
    "app=#{summary.dig('app', 'name')}",
    "version=#{summary.dig('version', 'version_string')}",
    "submitted=#{summary.fetch('review_submitted')}",
    "state=#{summary.dig('review_submission', 'state') || 'not-available'}",
    "no_op=#{summary.fetch('no_op')}",
    "no_op_reason=#{summary['no_op_reason'] || 'none'}"
  ].join(" ")
rescue MajiaCI::ASCStatusError, MajiaCI::ASCSubmissionError, KeyError,
       Errno::ENOENT, Errno::EACCES => e
  failure = {
    "schema_version" => 1,
    "submitted_at" => Time.now.utc.iso8601,
    "requested_marketing_version" => options[:marketing_version],
    "review_submitted" => false,
    "error" => e.message
  }
  write_json(options[:output], failure) if options[:output]
  if options[:github_summary]
    safe_message = e.message.to_s.gsub(/[\r\n]+/, " ").strip
    File.open(options[:github_summary], "a", 0o600) do |file|
      file.write("## ASC review submission\n\n- Failed: #{safe_message}\n")
    end
  end
  warn e.message
  exit 1
end
