# frozen_string_literal: true

require "json"
require "fileutils"

# Ruby Version Management Library
#
# This module automates the process of adding new Ruby versions to the devcontainer
# configuration. It updates the versions JSON file, potentially updates the
# default Ruby version, bumps the feature version, and updates test files.
module AddRubyVersion
  # Custom error class for version-related errors
  class Error < StandardError; end

  # File paths relative to the working directory
  VERSIONS_JSON_FILE = ".github/ruby-versions.json"
  FEATURE_JSON_FILE = "features/src/ruby/devcontainer-feature.json"
  README_FILE = "features/src/ruby/README.md"
  TEST_FILES = [
    "features/test/ruby/test.sh",
    "features/test/ruby/with_rbenv.sh"
  ].freeze

  # Version format pattern
  VERSION_PATTERN = /\d+\.\d+\.\d+/
  VERSION_EXACT_PATTERN = /\A#{VERSION_PATTERN}\z/

  class << self
    # Main entry point for adding a Ruby version
    #
    # @param version [String] The Ruby version to add (e.g., "3.4.0")
    # @param working_dir [String] The directory to operate in
    # @param output [IO] Output stream for messages (default: $stdout)
    # @return [Hash] Result with :success, :files_modified, and :message keys
    def call(version, working_dir:, output: $stdout)
      runner = Runner.new(version, working_dir: working_dir, output: output)
      runner.call
    end
  end

  # Runner class that performs the actual version addition
  class Runner
    # ANSI color codes
    COLORS = {
      reset: "\e[0m",
      green: "\e[32m",
      blue: "\e[34m",
      yellow: "\e[33m",
      red: "\e[31m",
      cyan: "\e[36m",
      magenta: "\e[35m"
    }.freeze

    # Emoji helpers
    EMOJI = {
      search: "🔍",
      edit: "📝",
      check: "✅",
      update: "🔄",
      info: "ℹ️",
      party: "🎉",
      file: "📄",
      bulb: "💡",
      error: "❌"
    }.freeze

    attr_reader :version, :working_dir, :output

    def initialize(version, working_dir:, output: $stdout)
      @version = version
      @working_dir = working_dir
      @output = output
    end

    def call
      validate_version_format!
      validate_files_exist!
      validate_version_not_duplicate!

      files_modified = []

      log("#{EMOJI[:search]} Checking current configuration...", :cyan)

      current_default = current_default_version
      log("Current default version: #{current_default}")
      log("New version to add: #{version}")

      # Add version to versions JSON file
      log("")
      log("#{EMOJI[:edit]} Adding #{version} to #{VERSIONS_JSON_FILE}...", :blue)
      add_version_to_versions_file
      log("#{EMOJI[:check]} Successfully added to #{VERSIONS_JSON_FILE}", :green)
      files_modified << VERSIONS_JSON_FILE

      # Check if new version should become the default
      if version_newer?(version, current_default)
        log("")
        log("#{EMOJI[:update]} New version #{version} is newer than current default #{current_default}", :yellow)

        update_default_version
        log("#{EMOJI[:check]} Updated default version to #{version}", :green)

        update_readme_default_version
        log("#{EMOJI[:check]} Updated README default version to #{version}", :green)

        log("")
        log("#{EMOJI[:update]} Bumping feature version...", :yellow)
        old_ver, new_ver = bump_feature_version
        log("#{EMOJI[:check]} Feature version bumped from #{old_ver} to #{new_ver}", :green)

        files_modified << FEATURE_JSON_FILE << README_FILE

        log("")
        log("#{EMOJI[:edit]} Updating test files...", :blue)
        TEST_FILES.each do |test_file|
          update_test_file(test_file)
          log("#{EMOJI[:check]} Updated #{test_file}", :green)
          files_modified << test_file
        end
      else
        log("")
        log("#{EMOJI[:info]} New version #{version} is not newer than current default #{current_default}", :cyan)
        log("Default version remains unchanged")
        log("")
        log("#{EMOJI[:info]} Skipping test file updates (new version #{version} is not newer than current default #{current_default})", :cyan)
      end

      # Success message
      log("")
      log("#{EMOJI[:party]} Successfully added Ruby version #{version}!", :green)
      log("")
      log("#{EMOJI[:file]} Files modified:", :blue)
      files_modified.each { |file| log("  • #{file}") }

      log("")
      log("#{EMOJI[:bulb]} Next steps:", :magenta)
      log("  1. Review the changes: git diff")
      log("  2. Commit the changes: git add . && git commit -m 'Add Ruby #{version}'")
      log("  3. Push changes: git push")

      { success: true, files_modified: files_modified }
    rescue Error => e
      log("#{EMOJI[:error]} Error: #{e.message}", :red)
      { success: false, error: e.message }
    end

    private

    def log(message, color = :reset)
      output.puts "#{COLORS[color]}#{message}#{COLORS[:reset]}"
    end

    def path_for(relative_path)
      File.join(working_dir, relative_path)
    end

    def validate_version_format!
      unless version.match?(VERSION_EXACT_PATTERN)
        raise Error, "Invalid version format. Expected format: x.y.z (e.g., 3.4.5)"
      end
    end

    def validate_files_exist!
      [VERSIONS_JSON_FILE, FEATURE_JSON_FILE, README_FILE, *TEST_FILES].each do |file|
        unless File.exist?(path_for(file))
          raise Error, "#{file} not found"
        end
      end
    end

    def validate_version_not_duplicate!
      versions = read_json(VERSIONS_JSON_FILE)
      if versions.include?(version)
        raise Error, "Version #{version} already exists in #{VERSIONS_JSON_FILE}"
      end
    end

    def read_json(relative_path)
      JSON.parse(File.read(path_for(relative_path)))
    end

    def write_json(relative_path, data)
      File.write(path_for(relative_path), JSON.pretty_generate(data) + "\n")
    end

    def current_default_version
      data = read_json(FEATURE_JSON_FILE)
      data.dig("options", "version", "default")
    end

    def version_newer?(new_version, current_version)
      parse_version(new_version) > parse_version(current_version)
    end

    def parse_version(version_string)
      Gem::Version.new(version_string)
    end

    def add_version_to_versions_file
      versions = read_json(VERSIONS_JSON_FILE)
      versions << version
      versions.uniq!
      versions.sort_by! { |v| Gem::Version.new(v) }.reverse!
      write_json(VERSIONS_JSON_FILE, versions)
    end

    def update_default_version
      data = read_json(FEATURE_JSON_FILE)
      data["options"]["version"]["default"] = version
      write_json(FEATURE_JSON_FILE, data)
    end

    def update_readme_default_version
      path = path_for(README_FILE)
      content = File.read(path)
      # Update the default value in the options table
      # Look for the pattern: | version | ... | string | X.Y.Z |
      updated = content.gsub(/(\| version \| [^|]+ \| string \| )(\d+\.\d+\.\d+)( \|)/) do
        "#{$1}#{version}#{$3}"
      end
      File.write(path, updated)
    end

    def bump_feature_version
      data = read_json(FEATURE_JSON_FILE)
      old_version = data["version"]
      new_version = increment_patch_version(old_version)
      data["version"] = new_version
      write_json(FEATURE_JSON_FILE, data)
      [old_version, new_version]
    end

    def increment_patch_version(version_string)
      parts = version_string.split(".").map(&:to_i)
      parts[2] += 1
      parts.join(".")
    end

    def update_test_file(relative_path)
      path = path_for(relative_path)
      content = File.read(path)
      updated = content.gsub(VERSION_PATTERN, version)
      File.write(path, updated)
    end
  end
end
