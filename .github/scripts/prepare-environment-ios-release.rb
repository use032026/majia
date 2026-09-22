#!/usr/bin/env ruby
# frozen_string_literal: true

require "base64"
require "fileutils"
require "open3"
require "optparse"
require "pathname"
require "tmpdir"
require_relative "lib/environment_ios_release"

options = {}
OptionParser.new do |parser|
  parser.on("--app-key KEY") { |value| options[:app_key] = value }
  parser.on("--app-name NAME") { |value| options[:app_name] = value }
  parser.on("--project-directory PATH") { |value| options[:project_directory] = value }
  parser.on("--container-path PATH") { |value| options[:container_path] = value }
  parser.on("--targets-json JSON") { |value| options[:targets_json] = value }
  parser.on("--marketing-version VERSION") { |value| options[:marketing_version] = value }
  parser.on("--upload-to-asc BOOLEAN") { |value| options[:upload_to_asc] = value }
  parser.on("--auto-create-store-version BOOLEAN") { |value| options[:auto_create_store_version] = value }
  parser.on("--update-asc-text-metadata BOOLEAN") { |value| options[:update_asc_text_metadata] = value }
  parser.on("--replace-asc-media BOOLEAN") { |value| options[:replace_asc_media] = value }
  parser.on("--metadata-template PATH") { |value| options[:metadata_template] = value }
  parser.on("--release-notes-json JSON") { |value| options[:release_notes_json] = value }
  parser.on("--github-output PATH") { |value| options[:github_output] = value }
end.parse!

def required_environment(name)
  value = ENV.fetch(name, "")
  raise MajiaCI::ReleaseInputError, "#{name} is required" if value.empty?

  value
end

def normalized_relative_path(value, name)
  path = Pathname.new(value)
  invalid = path.absolute? || value.start_with?("~") || ["\0", "\n", "\r"].any? { |char| value.include?(char) } ||
            path.each_filename.any? { |part| part == ".." } || path.cleanpath.to_s != value
  raise MajiaCI::ReleaseInputError, "#{name} must be a normalized repository-relative path" if invalid

  value
end

def command_success?(*command)
  _stdout, _stderr, status = Open3.capture3(*command)
  status.success?
end

def prepare_profiles(encoded, app_key)
  work_dir = nil
  bytes = Base64.strict_decode64(encoded.gsub(/\s+/, ""))
  runner_temp = required_environment("RUNNER_TEMP")
  work_dir = Dir.mktmpdir("#{app_key}-profiles-", runner_temp)
  payload = File.join(work_dir, "payload")
  profiles_dir = File.join(work_dir, "profiles")
  archive = File.join(work_dir, "profiles.tar.gz")
  File.binwrite(payload, bytes)
  FileUtils.mkdir_p(profiles_dir, mode: 0o700)

  if command_success?("security", "cms", "-D", "-i", payload)
    FileUtils.cp(payload, File.join(profiles_dir, "app.mobileprovision"))
    system("tar", "-czf", archive, "-C", profiles_dir, ".") ||
      raise(MajiaCI::ReleaseInputError, "failed to archive provisioning profile")
  elsif command_success?("tar", "-tzf", payload)
    FileUtils.cp(payload, archive)
  elsif command_success?("unzip", "-tq", payload)
    system("unzip", "-q", payload, "-d", profiles_dir) ||
      raise(MajiaCI::ReleaseInputError, "failed to extract provisioning profiles")
    profiles = Dir.glob(File.join(profiles_dir, "**", "*.mobileprovision"))
    raise MajiaCI::ReleaseInputError, "profile zip contains no .mobileprovision files" if profiles.empty?
    system("tar", "-czf", archive, "-C", profiles_dir, ".") ||
      raise(MajiaCI::ReleaseInputError, "failed to archive provisioning profiles")
  else
    raise MajiaCI::ReleaseInputError,
          "IOS_APPSTORE_PROFILE_BASE64 must decode to a mobileprovision, tar.gz, or zip"
  end

  Base64.strict_encode64(File.binread(archive))
rescue ArgumentError => e
  raise MajiaCI::ReleaseInputError, "IOS_APPSTORE_PROFILE_BASE64 is invalid Base64: #{e.message}"
ensure
  FileUtils.rm_rf(work_dir) if work_dir
end

begin
  required = %i[
    app_key app_name project_directory container_path targets_json marketing_version
    upload_to_asc auto_create_store_version update_asc_text_metadata replace_asc_media
    metadata_template release_notes_json github_output
  ]
  missing = required.reject { |key| options[key] && !options[key].empty? }
  raise MajiaCI::ReleaseInputError, "missing options: #{missing.join(', ')}" unless missing.empty?

  unless options.fetch(:app_key).match?(/\A[a-z0-9][a-z0-9-]*\z/)
    raise MajiaCI::ReleaseInputError, "app-key is invalid"
  end
  unless options.fetch(:app_name).match?(MajiaCI::EnvironmentIOSRelease::SAFE_NAME_PATTERN)
    raise MajiaCI::ReleaseInputError, "app-name is invalid"
  end
  unless options.fetch(:marketing_version).match?(MajiaCI::EnvironmentIOSRelease::VERSION_PATTERN)
    raise MajiaCI::ReleaseInputError, "marketing-version must contain three dot-separated integers"
  end

  upload_to_asc = MajiaCI::EnvironmentIOSRelease.boolean(options.fetch(:upload_to_asc), "upload_to_asc")
  auto_create = MajiaCI::EnvironmentIOSRelease.boolean(
    options.fetch(:auto_create_store_version),
    "auto_create_store_version"
  )
  update_text_metadata = MajiaCI::EnvironmentIOSRelease.boolean(
    options.fetch(:update_asc_text_metadata),
    "update_asc_text_metadata"
  )
  replace_media = MajiaCI::EnvironmentIOSRelease.boolean(
    options.fetch(:replace_asc_media),
    "replace_asc_media"
  )
  MajiaCI::EnvironmentIOSRelease.validate_release_switches!(
    upload_to_asc: upload_to_asc,
    auto_create_store_version: auto_create,
    update_asc_text_metadata: update_text_metadata,
    replace_asc_media: replace_media
  )

  team_id = required_environment("APPLE_TEAM_ID")
  bundle_id = required_environment("IOS_BUNDLE_ID")
  scheme = required_environment("IOS_SCHEME")
  unless team_id.match?(/\A[A-Z0-9]{10}\z/)
    raise MajiaCI::ReleaseInputError, "APPLE_TEAM_ID must be a 10-character Apple Team ID"
  end
  unless bundle_id.match?(/\A[A-Za-z0-9-]+(?:\.[A-Za-z0-9-]+)+\z/)
    raise MajiaCI::ReleaseInputError, "IOS_BUNDLE_ID is invalid"
  end
  unless scheme.match?(MajiaCI::EnvironmentIOSRelease::SAFE_NAME_PATTERN)
    raise MajiaCI::ReleaseInputError, "IOS_SCHEME is invalid"
  end

  project_directory = normalized_relative_path(options.fetch(:project_directory), "project-directory")
  container_path = normalized_relative_path(options.fetch(:container_path), "container-path")
  unless project_directory == "." || container_path.start_with?("#{project_directory}/")
    raise MajiaCI::ReleaseInputError, "container-path must be inside project-directory"
  end

  targets = MajiaCI::EnvironmentIOSRelease.parse_targets(options.fetch(:targets_json))
  workspace = File.realpath(ENV.fetch("GITHUB_WORKSPACE", Dir.pwd))
  metadata_template = normalized_relative_path(options.fetch(:metadata_template), "metadata-template")
  metadata_template_real = File.realpath(File.expand_path(metadata_template, workspace))
  unless metadata_template_real.start_with?(workspace + File::SEPARATOR) && File.file?(metadata_template_real)
    raise MajiaCI::ReleaseInputError, "metadata-template must resolve to a file inside GITHUB_WORKSPACE"
  end
  metadata = MajiaCI::EnvironmentIOSRelease.build_metadata(
    template_path: metadata_template_real,
    release_notes_json: options.fetch(:release_notes_json),
    update_text_metadata: update_text_metadata
  )

  app_key = options.fetch(:app_key)
  config_path = ".github/runtime-#{app_key}-ios-build.yml"
  metadata_path = ".github/runtime-#{app_key}-app-store-metadata.yml"
  config = MajiaCI::EnvironmentIOSRelease.build_config(
    app_name: options.fetch(:app_name),
    team_id: team_id,
    bundle_id: bundle_id,
    scheme: scheme,
    project_directory: project_directory,
    container_path: container_path,
    targets: targets,
    upload_to_asc: upload_to_asc,
    auto_create_store_version: auto_create,
    metadata_path: metadata_path
  )
  File.open(config_path, "w", 0o600) do |file|
    file.write(MajiaCI::EnvironmentIOSRelease.dump_yaml(config))
  end
  File.open(metadata_path, "w", 0o600) do |file|
    file.write(MajiaCI::EnvironmentIOSRelease.dump_yaml(metadata))
  end

  profiles_base64 = prepare_profiles(required_environment("IOS_APPSTORE_PROFILE_BASE64"), app_key)
  p8_base64 = ""
  if upload_to_asc
    key_id = required_environment("ASC_KEY_ID")
    issuer_id = required_environment("ASC_ISSUER_ID")
    unless key_id.match?(/\A[A-Z0-9]{10}\z/)
      raise MajiaCI::ReleaseInputError, "ASC_KEY_ID must contain 10 uppercase letters or digits"
    end
    unless issuer_id.match?(/\A[0-9a-fA-F]{8}(?:-[0-9a-fA-F]{4}){3}-[0-9a-fA-F]{12}\z/)
      raise MajiaCI::ReleaseInputError, "ASC_ISSUER_ID must be a UUID"
    end
    p8_base64 = MajiaCI::EnvironmentIOSRelease.normalize_p8(required_environment("ASC_API_KEY_P8"))
  end

  puts "::add-mask::#{profiles_base64}"
  puts "::add-mask::#{p8_base64}" unless p8_base64.empty?
  File.open(options.fetch(:github_output), "a", 0o600) do |output|
    output.puts "config_path=#{config_path}"
    output.puts "metadata_path=#{metadata_path}"
    output.puts "profiles_archive_base64=#{profiles_base64}"
    output.puts "asc_api_key_p8_base64=#{p8_base64}"
  end
  puts [
    "Prepared #{app_key}",
    "upload_to_asc=#{upload_to_asc}",
    "auto_create_store_version=#{auto_create}",
    "update_asc_text_metadata=#{update_text_metadata}",
    "replace_asc_media=#{replace_media}",
    "automatic_release=true"
  ].join(" ")
rescue MajiaCI::ReleaseInputError, Errno::ENOENT, Errno::EACCES => e
  warn e.message
  exit 1
end
