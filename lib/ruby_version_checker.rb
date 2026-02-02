# frozen_string_literal: true

require "json"
require "octokit"
require "set"
require_relative "console"

# Ruby Version Checker
#
# This class fetches available Ruby versions from rbenv/ruby-build,
# compares them with the current versions in the repository, and
# identifies new versions that should be added.
class RubyVersionChecker
  include Console

  # Custom error class for version checker errors
  class Error < StandardError; end

  # Minimum Ruby version to consider (non-EOL versions only)
  MIN_RUBY_VERSION = "3.2.0"

  # Ruby-build repository
  RUBY_BUILD_REPO = "rbenv/ruby-build"

  # File paths
  VERSIONS_JSON_FILE = ".github/ruby-versions.json"

  # Version format pattern (only stable releases: x.y.z)
  VERSION_PATTERN = /\A\d+\.\d+\.\d+\z/

  class << self
    # Main entry point for checking Ruby versions
    #
    # @param working_dir [String] The directory to operate in
    # @param github_token [String, nil] GitHub token for API requests
    # @param output [IO] Output stream for messages (default: $stdout)
    # @return [Hash] Result with :success, :new_versions, and :current_versions keys
    def check(working_dir:, github_token: nil, output: $stdout)
      new(working_dir: working_dir, github_token: github_token, output: output).check
    end
  end

  attr_reader :working_dir, :github_token, :output

  def initialize(working_dir:, github_token: nil, output: $stdout)
    @working_dir = working_dir
    @github_token = github_token || ENV["GITHUB_TOKEN"]
    @output = output
  end

  # Check for new Ruby versions without adding them
  #
  # @return [Hash] Result with :success, :new_versions, and :current_versions keys
  def check
    log("Checking for new Ruby versions...", :cyan, emoji: :search)

    current_versions = load_current_versions
    log("Found #{current_versions.size} versions in local config", emoji: :info)

    available_versions = fetch_available_versions
    log("Found #{available_versions.size} versions in ruby-build (>= #{MIN_RUBY_VERSION})", emoji: :info)

    new_versions = find_new_versions(available_versions, current_versions)

    if new_versions.empty?
      log("")
      log("No new Ruby versions found", :green, emoji: :check)
      { success: true, new_versions: [], current_versions: current_versions }
    else
      log("")
      log("Found #{new_versions.size} new version(s):", :yellow, emoji: :new)
      new_versions.each { |v| log("  • #{v}") }
      { success: true, new_versions: new_versions, current_versions: current_versions }
    end
  rescue Error => e
    log("Error: #{e.message}", :red, emoji: :error)
    { success: false, error: e.message }
  end

  private

  def path_for(relative_path)
    File.join(working_dir, relative_path)
  end

  # Create an Octokit client
  #
  # @return [Octokit::Client] Configured GitHub client
  def github_client
    @github_client ||= Octokit::Client.new(access_token: github_token)
  end

  # Load current versions from the local JSON file
  #
  # @return [Array<String>] List of current Ruby versions
  def load_current_versions
    path = path_for(VERSIONS_JSON_FILE)
    unless File.exist?(path)
      raise Error, "#{VERSIONS_JSON_FILE} not found"
    end

    JSON.parse(File.read(path))
  rescue JSON::ParserError => e
    raise Error, "Failed to parse #{VERSIONS_JSON_FILE}: #{e.message}"
  end

  # Fetch available Ruby versions from ruby-build repository
  #
  # @return [Array<String>] List of available Ruby versions
  def fetch_available_versions
    log("Fetching versions from ruby-build...", :blue, emoji: :fetch)

    # First, get the latest release tag
    latest_tag = fetch_latest_release_tag
    log("Using ruby-build release: #{latest_tag}", emoji: :info)

    # Fetch the share/ruby-build directory contents
    versions = fetch_ruby_build_versions(latest_tag)

    # Filter to only stable versions >= MIN_RUBY_VERSION
    filter_versions(versions)
  end

  # Fetch the latest release tag from ruby-build
  #
  # @return [String] The latest release tag
  def fetch_latest_release_tag
    release = github_client.latest_release(RUBY_BUILD_REPO)
    release.tag_name
  rescue Octokit::Unauthorized
    raise Error, "GitHub API authentication failed. Check your token."
  rescue Octokit::Forbidden
    if github_token
      raise Error, "GitHub API rate limit exceeded or token lacks permissions."
    else
      raise Error, "GitHub API rate limit exceeded. Set GITHUB_TOKEN environment variable."
    end
  rescue Octokit::NotFound
    raise Error, "Could not find latest release for #{RUBY_BUILD_REPO}"
  rescue Octokit::Error => e
    raise Error, "GitHub API error: #{e.message}"
  end

  # Fetch Ruby version files from ruby-build repository
  #
  # @param tag [String] The git tag to fetch from
  # @return [Array<String>] List of version file names
  def fetch_ruby_build_versions(tag)
    contents = github_client.contents(RUBY_BUILD_REPO, path: "share/ruby-build", ref: tag)
    contents.map(&:name)
  rescue Octokit::Unauthorized
    raise Error, "GitHub API authentication failed. Check your token."
  rescue Octokit::Forbidden
    if github_token
      raise Error, "GitHub API rate limit exceeded or token lacks permissions."
    else
      raise Error, "GitHub API rate limit exceeded. Set GITHUB_TOKEN environment variable."
    end
  rescue Octokit::NotFound
    raise Error, "Could not find ruby-build versions at tag #{tag}"
  rescue Octokit::Error => e
    raise Error, "GitHub API error: #{e.message}"
  end

  # Filter versions to only include stable releases >= MIN_RUBY_VERSION
  #
  # @param versions [Array<String>] Raw version names from ruby-build
  # @return [Array<String>] Filtered and sorted versions
  def filter_versions(versions)
    min_version = Gem::Version.new(MIN_RUBY_VERSION)

    versions
      .select { |v| v.match?(VERSION_PATTERN) }
      .select { |v| Gem::Version.new(v) >= min_version }
      .sort_by { |v| Gem::Version.new(v) }
      .reverse
  end

  # Find versions that are in available but not in current
  #
  # @param available [Array<String>] Available versions from ruby-build
  # @param current [Array<String>] Current versions in local config
  # @return [Array<String>] New versions to add (sorted descending)
  def find_new_versions(available, current)
    current_set = current.to_set
    available
      .reject { |v| current_set.include?(v) }
      .sort_by { |v| Gem::Version.new(v) }
      .reverse
  end
end
