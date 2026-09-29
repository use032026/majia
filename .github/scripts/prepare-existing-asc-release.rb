#!/usr/bin/env ruby
# frozen_string_literal: true

require "base64"
require "fileutils"
require "json"
require "optparse"
require "pathname"
require_relative "lib/environment_ios_release"

options = {}
OptionParser.new do |parser|
  parser.on("--app-name NAME") { |value| options[:app_name] = value }
  parser.on("--project-directory PATH") { |value| options[:project_directory] = value }
  parser.on("--container-path PATH") { |value| options[:container_path] = value }
  parser.on("--targets-json JSON") { |value| options[:targets_json] = value }
  parser.on("--marketing-version VERSION") { |value| options[:marketing_version] = value }
  parser.on("--metadata-template PATH") { |value| options[:metadata_template] = value }
  parser.on("--release-notes-json JSON") { |value| options[:release_notes_json] = value }
  parser.on("--config-output PATH") { |value| options[:config_output] = value }
  parser.on("--metadata-output PATH") { |value| options[:metadata_output] = value }
  parser.on("--key-output PATH") { |value| options[:key_output] = value }
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

def output_path_under(root, value, name)
  root_path = File.realpath(root)
  path = File.expand_path(value, root_path)
  unless path.start_with?(root_path + File::SEPARATOR)
    raise MajiaCI::ReleaseInputError, "#{name} must remain under #{root_path}"
  end

  path
end

def write_private_file(path, contents)
  FileUtils.mkdir_p(File.dirname(path), mode: 0o700)
  File.open(path, "wb", 0o600) { |file| file.write(contents) }
end

begin
  required = %i[
    app_name project_directory container_path targets_json marketing_version metadata_template
    release_notes_json config_output metadata_output key_output github_output
  ]
  missing = required.reject { |key| options[key] && !options[key].empty? }
  raise MajiaCI::ReleaseInputError, "missing options: #{missing.join(', ')}" unless missing.empty?

  release = MajiaCI::EnvironmentIOSRelease
  unless options.fetch(:app_name).match?(release::SAFE_NAME_PATTERN)
    raise MajiaCI::ReleaseInputError, "app-name is invalid"
  end
  unless options.fetch(:marketing_version).match?(release::VERSION_PATTERN)
    raise MajiaCI::ReleaseInputError, "marketing-version must contain three dot-separated integers"
  end

  team_id = required_environment("APPLE_TEAM_ID")
  bundle_id = required_environment("IOS_BUNDLE_ID")
  scheme = required_environment("IOS_SCHEME")
  key_id = required_environment("ASC_KEY_ID")
  issuer_id = required_environment("ASC_ISSUER_ID")
  unless team_id.match?(/\A[A-Z0-9]{10}\z/)
    raise MajiaCI::ReleaseInputError, "APPLE_TEAM_ID must be a 10-character Apple Team ID"
  end
  unless bundle_id.match?(/\A[A-Za-z0-9-]+(?:\.[A-Za-z0-9-]+)+\z/)
    raise MajiaCI::ReleaseInputError, "IOS_BUNDLE_ID is invalid"
  end
  unless scheme.match?(release::SAFE_NAME_PATTERN)
    raise MajiaCI::ReleaseInputError, "IOS_SCHEME is invalid"
  end
  unless key_id.match?(/\A[A-Z0-9]{10}\z/)
    raise MajiaCI::ReleaseInputError, "ASC_KEY_ID must contain 10 uppercase letters or digits"
  end
  unless issuer_id.match?(/\A[0-9a-fA-F]{8}(?:-[0-9a-fA-F]{4}){3}-[0-9a-fA-F]{12}\z/)
    raise MajiaCI::ReleaseInputError, "ASC_ISSUER_ID must be a UUID"
  end

  workspace = File.realpath(ENV.fetch("GITHUB_WORKSPACE", Dir.pwd))
  runner_temp = File.realpath(required_environment("RUNNER_TEMP"))
  project_directory = normalized_relative_path(options.fetch(:project_directory), "project-directory")
  container_path = normalized_relative_path(options.fetch(:container_path), "container-path")
  unless project_directory == "." || container_path.start_with?("#{project_directory}/")
    raise MajiaCI::ReleaseInputError, "container-path must be inside project-directory"
  end

  template_path = normalized_relative_path(options.fetch(:metadata_template), "metadata-template")
  template_real = File.realpath(File.expand_path(template_path, workspace))
  unless template_real.start_with?(workspace + File::SEPARATOR) && File.file?(template_real)
    raise MajiaCI::ReleaseInputError, "metadata-template must resolve inside GITHUB_WORKSPACE"
  end
  metadata_relative = normalized_relative_path(options.fetch(:metadata_output), "metadata-output")
  metadata_path = output_path_under(workspace, metadata_relative, "metadata-output")
  config_path = output_path_under(runner_temp, options.fetch(:config_output), "config-output")
  key_path = output_path_under(runner_temp, options.fetch(:key_output), "key-output")

  metadata = release.build_metadata(
    template_path: template_real,
    release_notes_json: options.fetch(:release_notes_json),
    update_text_metadata: true
  )
  unless metadata.fetch("localizations", {}).values.any? { |locale| !locale.fetch("whats_new", "").strip.empty? }
    raise MajiaCI::ReleaseInputError, "release-notes-json must contain at least one non-empty whats_new value"
  end

  targets = release.parse_targets(options.fetch(:targets_json))
  config = release.build_config(
    app_name: options.fetch(:app_name),
    team_id: team_id,
    bundle_id: bundle_id,
    scheme: scheme,
    project_directory: project_directory,
    container_path: container_path,
    targets: targets,
    upload_to_asc: true,
    auto_create_store_version: true,
    metadata_path: metadata_relative
  )

  write_private_file(config_path, release.dump_yaml(config))
  write_private_file(metadata_path, release.dump_yaml(metadata))
  encoded_key = release.normalize_p8(required_environment("ASC_API_KEY_P8"))
  write_private_file(key_path, Base64.strict_decode64(encoded_key))

  File.open(options.fetch(:github_output), "a", 0o600) do |output|
    output.puts "config_path=#{config_path}"
    output.puts "metadata_path=#{metadata_path}"
    output.puts "key_path=#{key_path}"
  end
  puts "Prepared existing-build ASC release for #{bundle_id} version #{options.fetch(:marketing_version)}"
rescue MajiaCI::ReleaseInputError, ArgumentError, KeyError, Errno::ENOENT, Errno::EACCES => e
  warn e.message
  exit 1
end
