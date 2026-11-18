#!/usr/bin/env ruby
# frozen_string_literal: true

require "json"
require "optparse"

# All errors, including authentication/input/file failures, terminate with a
# fixed safe code. Never print an upstream message, response, notes or backtrace.
summary = { "schema_version" => 1, "status" => "failed", "error_code" => "configuration_or_evidence_io_failed",
            "write_attempted" => false, "may_have_written" => false, "verified" => false }
output = nil
writer_invoked = false
begin
  require_relative "lib/deynu_review_notes"
  options = {}
  OptionParser.new { |parser| parser.on("--output PATH") { |value| options[:output] = value } }.parse!
  raise ArgumentError unless ARGV.empty?
  output = options[:output] || ENV["DEYNU_REVIEW_OUTPUT"]
  apply_text = ENV.fetch("DEYNU_REVIEW_APPLY", "false")
  raise ArgumentError unless %w[true false].include?(apply_text)
  apply = apply_text == "true"
  version = ENV.fetch("DEYNU_REVIEW_VERSION")
  build = ENV.fetch("DEYNU_REVIEW_BUILD")
  expected_id = ENV.fetch("DEYNU_REVIEW_EXPECTED_BUILD_ID")
  unless version == MajiaCI::DeynuReviewNotes::VERSION && build == MajiaCI::DeynuReviewNotes::BUILD_NUMBER &&
         expected_id == MajiaCI::DeynuReviewNotes::BUILD_ID
    raise ArgumentError
  end
  notes = nil
  if ENV.key?("DEYNU_REVIEW_NOTES_FILE")
    raise ArgumentError if ENV.key?("DEYNU_REVIEW_NOTES_TEXT")
    path = ENV.fetch("DEYNU_REVIEW_NOTES_FILE")
    File.open(path, File::RDONLY | File::NOFOLLOW) do |file|
      stat = file.stat
      raise ArgumentError unless stat.file? && stat.uid == Process.uid && (stat.mode & 0o777) == 0o600
      notes = file.read(16_001).force_encoding(Encoding::UTF_8)
    end
  elsif ENV.key?("DEYNU_REVIEW_NOTES_TEXT")
    notes = ENV.fetch("DEYNU_REVIEW_NOTES_TEXT").dup.force_encoding(Encoding::UTF_8)
  end
  # Reject unsafe desired input before parsing credentials or making a request.
  if notes || apply
    MajiaCI::DeynuReviewNotes.send(:validate_notes, notes, desired: true, nonempty: apply)
  end
  expected_hash = ENV["DEYNU_REVIEW_EXPECTED_CURRENT_HASH"]
  if apply && !(expected_hash.is_a?(String) && expected_hash.match?(MajiaCI::DeynuReviewNotes::HASH))
    raise ArgumentError
  end
  key_id = ENV.fetch("ASC_KEY_ID")
  issuer_id = ENV.fetch("ASC_ISSUER_ID")
  MajiaCI::ASCReviewStatus.validate_inputs!(bundle_id: MajiaCI::DeynuReviewNotes::BUNDLE_ID,
    marketing_version: version, key_id: key_id, issuer_id: issuer_id)
  key = MajiaCI::ASCReviewStatus.normalize_private_key(ENV.fetch("ASC_API_KEY_P8"))
  client = MajiaCI::DeynuReviewNotesClient.new(key: key, key_id: key_id, issuer_id: issuer_id)
  writer_invoked = true
  summary = MajiaCI::DeynuReviewNotes.sync(client: client, marketing_version: version, build_number: build,
    expected_build_id: expected_id, apply: apply, desired_notes: notes, expected_current_hash: expected_hash)
rescue Exception # rubocop:disable Lint/RescueException -- top-level redaction, including load/parse errors
  # An interruption escaping before assignment cannot establish that no write
  # happened. Preserve uncertainty without exposing any exception details.
  if writer_invoked
    summary = summary.merge("write_attempted" => nil, "may_have_written" => true, "write_outcome_unknown" => true)
  end
end

begin
  if output
    File.open(output, File::WRONLY | File::CREAT | File::EXCL, 0o600) do |file|
      file.write(JSON.generate(summary)); file.write("\n")
    end
  end
rescue Exception # rubocop:disable Lint/RescueException
  summary = summary.merge("status" => "failed", "error_code" => "configuration_or_evidence_io_failed")
end
puts JSON.generate(summary)
exit(summary["error_code"] ? 1 : 0)
