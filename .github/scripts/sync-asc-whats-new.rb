#!/usr/bin/env ruby
# frozen_string_literal: true

require "base64"
require "json"
require "openssl"
require "optparse"
require_relative "lib/asc_whats_new"
require_relative "lib/environment_ios_release"

options = {}
OptionParser.new do |parser|
  parser.on("--bundle-id BUNDLE_ID") { |value| options[:bundle_id] = value }
  parser.on("--marketing-version VERSION") { |value| options[:marketing_version] = value }
  parser.on("--release-notes-json JSON") { |value| options[:release_notes_json] = value }
  parser.on("--output PATH") { |value| options[:output] = value }
  parser.on("--github-output PATH") { |value| options[:github_output] = value }
end.parse!

def required_environment(name)
  value = ENV.fetch(name, "")
  raise MajiaCI::ASCWhatsNewError, "#{name} is required" if value.empty?

  value
end

def write_json(path, value)
  File.open(path, "w", 0o600) do |file|
    file.write(JSON.pretty_generate(value))
    file.write("\n")
  end
end

begin
  required = %i[bundle_id marketing_version release_notes_json output github_output]
  missing = required.reject { |key| options[key] && !options[key].empty? }
  raise MajiaCI::ASCWhatsNewError, "missing options: #{missing.join(', ')}" unless missing.empty?

  key_id = required_environment("ASC_KEY_ID")
  issuer_id = required_environment("ASC_ISSUER_ID")
  MajiaCI::ASCReviewStatus.validate_inputs!(
    bundle_id: options.fetch(:bundle_id),
    marketing_version: options.fetch(:marketing_version),
    key_id: key_id,
    issuer_id: issuer_id
  )
  encoded_key = MajiaCI::EnvironmentIOSRelease.normalize_p8(required_environment("ASC_API_KEY_P8"))
  key = OpenSSL::PKey.read(Base64.strict_decode64(encoded_key))
  release_notes = JSON.parse(options.fetch(:release_notes_json))
  client = MajiaCI::ASCClient.new(key: key, key_id: key_id, issuer_id: issuer_id)
  summary = MajiaCI::ASCWhatsNew.sync(
    client: client,
    bundle_id: options.fetch(:bundle_id),
    marketing_version: options.fetch(:marketing_version),
    release_notes: release_notes
  )

  write_json(options.fetch(:output), summary)
  File.open(options.fetch(:github_output), "a", 0o600) do |output|
    output.puts "asc_whats_new_updated=#{summary.fetch('text_metadata_updated')}"
    output.puts "asc_whats_new_locales=#{summary.fetch('updated').map { |entry| entry.fetch('applied_locale') }.join(',')}"
  end
  puts [
    "ASC What's New updated",
    "version=#{summary.dig('version', 'version_string')}",
    "locales=#{summary.fetch('updated').map { |entry| entry.fetch('applied_locale') }.join(',')}",
    "verified=#{summary.fetch('updated').all? { |entry| entry.fetch('verified') }}"
  ].join(" ")
rescue MajiaCI::ASCStatusError, MajiaCI::ASCWhatsNewError, MajiaCI::ReleaseInputError,
       JSON::ParserError, KeyError, ArgumentError, Errno::ENOENT, Errno::EACCES,
       OpenSSL::PKey::PKeyError => e
  failure = {
    "schema_version" => 1,
    "requested_marketing_version" => options[:marketing_version],
    "text_metadata_updated" => false,
    "error" => e.message,
    "checked_at" => Time.now.utc.iso8601
  }
  write_json(options[:output], failure) if options[:output]
  warn e.message
  exit 1
end
