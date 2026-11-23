#!/usr/bin/env ruby
# frozen_string_literal: true

require "json"
require "optparse"
require "time"
require_relative "lib/asc_review_cancellation"

options = { version: "1.0.8" }
OptionParser.new do |parser|
  parser.on("--version VERSION", %w[1.0.8 1.0.11]) { |value| options[:version] = value }
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
  File.open(path, "w", 0o600) { |file| file.write(JSON.pretty_generate(value) + "\n") }
end

begin
  cancellation = MajiaCI::ASCReviewCancellation
  target = options[:version] == "1.0.11" ? cancellation::TRIPDELTA_111 : cancellation::TRIPDELTA_108
  missing = %i[output github_output github_summary].reject { |key| options[key] && !options[key].empty? }
  raise MajiaCI::ASCStatusError, "missing options: #{missing.join(', ')}" unless missing.empty?
  unless required_environment("IOS_BUNDLE_ID") == "com.tripdelta.lite.app"
    raise MajiaCI::ASCStatusError, "production bundle does not match the authorized Trip Delta app"
  end
  key_id = required_environment("ASC_KEY_ID")
  issuer_id = required_environment("ASC_ISSUER_ID")
  MajiaCI::ASCReviewStatus.validate_inputs!(
    bundle_id: "com.tripdelta.lite.app",
    marketing_version: target.fetch(:version),
    key_id: key_id,
    issuer_id: issuer_id
  )
  key = MajiaCI::ASCReviewStatus.normalize_private_key(required_environment("ASC_API_KEY_P8"))
  client = MajiaCI::ASCClient.new(key: key, key_id: key_id, issuer_id: issuer_id)
  summary = cancellation.cancel(client: client, target: target)
  write_json(options.fetch(:output), summary)
  File.open(options.fetch(:github_summary), "a", 0o600) do |file|
    file.puts "## Trip Delta #{options[:version]} review withdrawal"
    file.puts
    file.puts "- Cancellation receipt saved to the retained JSON artifact."
    file.puts "- Scope: app 6822704143, version #{options[:version]}, authorized review batch only."
  end
  File.open(options.fetch(:github_output), "a", 0o600) { |file| file.puts "cancellation_complete=true" }
  puts "Trip Delta #{options[:version]} review withdrawal completed; see retained receipt."
rescue MajiaCI::ASCStatusError, MajiaCI::ASCCancellationError, KeyError,
       Errno::ENOENT, Errno::EACCES => e
  failure = {
    "schema_version" => 1,
    "checked_at" => Time.now.utc.iso8601,
    "requested_marketing_version" => options[:version],
    "cancellation_complete" => false,
    "error" => e.message
  }
  failure["evidence"] = e.evidence if e.respond_to?(:evidence) && e.evidence
  write_json(options[:output], failure) if options[:output]
  if options[:github_summary]
    File.open(options[:github_summary], "a", 0o600) do |file|
      file.puts "## Trip Delta #{options[:version]} review withdrawal"
      file.puts
      file.puts "- Withdrawal not verified complete. Inspect retained JSON evidence."
    end
  end
  warn e.message
  exit 1
end
