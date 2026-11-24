#!/usr/bin/env ruby
# frozen_string_literal: true

require "json"
require "optparse"
require_relative "lib/asc_jufu_isolated_submission"

options = { execute: false }

def write_jufu_receipt(path, receipt)
  File.open(path, File::WRONLY | File::CREAT | File::TRUNC, 0o600) do |file|
    file.chmod(0o600)
    file.puts(JSON.pretty_generate(receipt))
  end
end

def required_jufu_env(name)
  value = ENV.fetch(name, "")
  raise MajiaCI::ASCSubmissionError, "required protected configuration is absent" if value.empty?
  value
end

begin
  OptionParser.new do |parser|
    parser.on("--execute-submit BOOLEAN") do |value|
      raise OptionParser::InvalidArgument, "execute-submit must be true or false" unless %w[true false].include?(value)
      options[:execute] = value == "true"
    end
    parser.on("--output PATH") { |value| options[:output] = value }
    parser.on("--github-output PATH") { |value| options[:github_output] = value }
    parser.on("--github-summary PATH") { |value| options[:github_summary] = value }
  end.parse!
  unless %i[output github_output github_summary].all? { |key| options[key].is_a?(String) && !options[key].empty? } && ARGV.empty?
    raise MajiaCI::ASCSubmissionError, "receipt output paths are required; no variable App or version is accepted"
  end
  if options[:execute] && Time.now.getlocal("+08:00").wday.zero?
    raise MajiaCI::ASCSubmissionError, "formal submissions are disabled on Sundays in Asia/Shanghai"
  end
  unless required_jufu_env("IOS_BUNDLE_ID") == "com.lunelle.lite"
    raise MajiaCI::ASCSubmissionError, "protected bundle is not the authorized Jufu app"
  end
  key_id = required_jufu_env("ASC_KEY_ID")
  issuer_id = required_jufu_env("ASC_ISSUER_ID")
  MajiaCI::ASCReviewStatus.validate_inputs!(bundle_id: "com.lunelle.lite", marketing_version: "1.0.3", key_id: key_id, issuer_id: issuer_id)
  key = MajiaCI::ASCReviewStatus.normalize_private_key(required_jufu_env("ASC_API_KEY_P8"))
  client = MajiaCI::ASCClient.new(key: key, key_id: key_id, issuer_id: issuer_id)
  receipt = MajiaCI::ASCJufuIsolatedSubmission.run(client: client, execute: options.fetch(:execute))
  verified = options[:execute] ? receipt["review_submitted"] == true : receipt["ready_to_submit"] == true
  raise MajiaCI::ASCJufuIsolatedSubmissionError.new("result_not_verified", evidence: receipt) unless verified
  write_jufu_receipt(options.fetch(:output), receipt)
  File.open(options.fetch(:github_summary), "a", 0o600) do |file|
    file.puts "## Jufu 1.0.3 isolated review"
    file.puts "- Fixed App/version/build only; existing unrelated batches are never changed."
    file.puts "- Formal review verified: #{receipt['review_submitted'] == true}"
    file.puts "- Dry run: #{!options.fetch(:execute)}"
    file.puts "- Inspect protected JSON for the exact phase and receipt."
  end
  File.open(options.fetch(:github_output), "a", 0o600) do |file|
    file.puts "review_submitted=#{receipt['review_submitted'] == true}"
    file.puts "dry_run=#{!options.fetch(:execute)}"
  end
  puts "Jufu isolated review check finished; inspect retained receipt."
rescue StandardError => error
  failure = { "schema_version" => 1, "checked_at" => Time.now.utc.iso8601,
              "requested_marketing_version" => "1.0.3", "review_submitted" => false,
              "execute_requested" => options[:execute], "error" => "isolated_submission_not_verified" }
  if error.is_a?(MajiaCI::ASCJufuIsolatedSubmissionError) && error.evidence
    failure["evidence"] = error.evidence
  end
  write_jufu_receipt(options[:output], failure) if options[:output]
  if options[:github_summary]
    File.open(options[:github_summary], "a", 0o600) do |file|
      file.puts "## Jufu 1.0.3 isolated review"
      file.puts "- Not verified. Inspect retained JSON before any retry; no unrelated batch may be modified."
    end
  end
  warn "Jufu isolated review was not verified"
  exit 1
end
