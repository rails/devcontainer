# frozen_string_literal: true

require "json"
require "fileutils"

# Ruby Version Adder Service
#
# This service handles the business logic for adding new Ruby versions to the
# devcontainer configuration. It is a pure business logic class with no
# presentation concerns (no output, colors, or emojis).
#
# Use AddRubyVersion for CLI usage with formatted output.
# Use this class directly when you need silent operation or custom output handling.
class RubyVersionAdder
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
    # Add a Ruby version to the configuration
    #
    # @param version [String] The Ruby version to add (e.g., "3.4.0")
    # @param working_dir [String] The directory to operate in
    # @return [Hash] Result with :success, :files_modified, :default_updated, :previous_default, and other metadata
    def call(version, working_dir:)
      new(version, working_dir: working_dir).call
    end
  end

  attr_reader :version, :working_dir

  def initialize(version, working_dir:)
    @version = version
    @working_dir = working_dir
  end

  def call
    validate_version_format!
    validate_files_exist!
    validate_version_not_duplicate!

    files_modified = []
    previous_default = current_default_version

    # Add version to versions JSON file
    add_version_to_versions_file
    files_modified << VERSIONS_JSON_FILE

    result = {
      success: true,
      files_modified: files_modified,
      version: version,
      previous_default: previous_default,
      default_updated: false
    }

    # Check if new version should become the default
    if version_newer?(version, previous_default)
      update_default_version
      update_readme_default_version
      old_feature_version, new_feature_version = bump_feature_version
      files_modified << FEATURE_JSON_FILE << README_FILE

      TEST_FILES.each do |test_file|
        update_test_file(test_file)
        files_modified << test_file
      end

      result[:default_updated] = true
      result[:new_default] = version
      result[:old_feature_version] = old_feature_version
      result[:new_feature_version] = new_feature_version
    end

    result[:files_modified] = files_modified.uniq
    result
  rescue Error => e
    { success: false, error: e.message }
  end

  # Expose helper methods for use by other modules
  def current_default_version
    data = read_json(FEATURE_JSON_FILE)
    data.dig("options", "version", "default")
  rescue Errno::ENOENT
    raise Error, "#{FEATURE_JSON_FILE} not found"
  end

  def version_newer?(new_version, current_version)
    parse_version(new_version) > parse_version(current_version)
  end

  private

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
    json = JSON.pretty_generate(data, indent: "    ")
    File.write(path_for(relative_path), json + "\n")
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
    updated = content.gsub(/(\| version \| [^|]+ \| string \| )#{VERSION_PATTERN}( \|)/) do
      "#{$1}#{version}#{$2}"
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
