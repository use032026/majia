#!/usr/bin/env ruby
# frozen_string_literal: true

require "json"
require "optparse"
require_relative "lib/asc_tripdelta_110_cancellation"

options = { execute_cancel: false }
OptionParser.new do |parser|
  parser.on("--replacement-build-id ID") { |value| options[:replacement_build_id] = value }
  parser.on("--replacement-build-number NUMBER") { |value| options[:replacement_build_number] = value }
  parser.on("--execute-cancel BOOLEAN") do |value|
    raise OptionParser::InvalidArgument, "execute-cancel must be true or false" unless %w[true false].include?(value)
    options[:execute_cancel] = value == "true"
  end
  parser.on("--output PATH") { |value| options[:output] = value }
  parser.on("--github-output PATH") { |value| options[:github_output] = value }
  parser.on("--github-summary PATH") { |value| options[:github_summary] = value }
end.parse!

def required_110_environment(name)
  value = ENV.fetch(name, "")
  raise MajiaCI::ASCStatusError, "#{name} is required" if value.empty?
  value
end

def write_110_json(path, value)
  File.open(path, File::WRONLY | File::CREAT | File::TRUNC, 0o600) do |file|
    file.chmod(0o600)
    file.puts(JSON.pretty_generate(value))
  end
end

begin
  required = %i[replacement_build_id replacement_build_number output github_output github_summary]
  unless required.all? { |key| options[key].is_a?(String) && !options[key].empty? }
    raise MajiaCI::ASCStatusError, "exact replacement build and output options are required"
  end
  unless options.fetch(:replacement_build_id).match?(/\A[0-9a-fA-F]{8}(?:-[0-9a-fA-F]{4}){3}-[0-9a-fA-F]{12}\z/) &&
         options.fetch(:replacement_build_id).downcase != "a130321b-d00b-4cda-95ca-d66d00e2c7e8" &&
         options.fetch(:replacement_build_number).match?(/\A[1-9][0-9]{0,17}\z/) && options.fetch(:replacement_build_number).to_i > 1
    raise MajiaCI::ASCStatusError, "replacement must be a distinct exact new build"
  end
  unless required_110_environment("IOS_BUNDLE_ID") == "com.tripdelta.lite.app"
    raise MajiaCI::ASCStatusError, "protected bundle is not the authorized Trip Delta app"
  end
  key_id = required_110_environment("ASC_KEY_ID")
  issuer_id = required_110_environment("ASC_ISSUER_ID")
  MajiaCI::ASCReviewStatus.validate_inputs!(bundle_id: "com.tripdelta.lite.app", marketing_version: "1.0.10", key_id: key_id, issuer_id: issuer_id)
  key = MajiaCI::ASCReviewStatus.normalize_private_key(required_110_environment("ASC_API_KEY_P8"))
  client = MajiaCI::ASCClient.new(key: key, key_id: key_id, issuer_id: issuer_id)
  receipt = MajiaCI::ASCTripDelta110Cancellation.cancel(
    client: client, replacement_build_id: options.fetch(:replacement_build_id),
    replacement_build_number: options.fetch(:replacement_build_number), execute: options.fetch(:execute_cancel)
  )
  unless receipt["completed"] == true || (!options[:execute_cancel] && receipt["ready_to_cancel"] == true && receipt["cancel_requested"] == false)
    raise MajiaCI::ASCCancellationError.new("cancellation result is not verified", evidence: receipt)
  end
  write_110_json(options.fetch(:output), receipt)
  File.open(options.fetch(:github_summary), "a", 0o600) do |file|
    file.puts "## Trip Delta 1.0.10 old review withdrawal"
    file.puts "- Exact fixed old review scope; replacement readiness and receipt retained in protected JSON."
    file.puts(options[:execute_cancel] ? "- Withdrawal execution requested; inspect completed/readback fields." : "- Read-only preflight only; no Apple write requested.")
  end
  File.open(options.fetch(:github_output), "a", 0o600) do |file|
    file.puts "cancellation_complete=#{receipt['completed'] == true}"
    file.puts "dry_run=#{!options.fetch(:execute_cancel)}"
  end
  puts "Trip Delta 1.0.10 old review check finished; inspect retained receipt."
rescue StandardError => error
  failure = { "schema_version" => 1, "checked_at" => Time.now.utc.iso8601,
              "requested_marketing_version" => "1.0.10", "cancellation_complete" => false,
              "execute_requested" => options[:execute_cancel], "error" => "cancellation_not_verified" }
  failure["evidence"] = error.evidence if error.is_a?(MajiaCI::ASCCancellationError) && error.evidence
  write_110_json(options[:output], failure) if options[:output]
  if options[:github_summary]
    File.open(options[:github_summary], "a", 0o600) do |file|
      file.puts "## Trip Delta 1.0.10 old review withdrawal"
      file.puts "- Not verified complete. Inspect retained JSON before any retry; no build binding or submission was requested."
    end
  end
  warn "Trip Delta 1.0.10 old review withdrawal was not verified"
  exit 1
end
