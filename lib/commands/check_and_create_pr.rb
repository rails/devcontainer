# frozen_string_literal: true

require_relative "../ruby_version_checker"
require_relative "../ruby_version_pr_creator"
require_relative "../ruby_version_adder"
require_relative "../console"

module Commands
  # Check and Create PR for New Ruby Versions
  #
  # This class orchestrates the entire workflow:
  # 1. Check for new Ruby versions from ruby-build
  # 2. Add any new versions to the repository
  # 3. Create a pull request with the changes
  class CheckAndCreatePR
    include Console

    # Custom error class
    class Error < StandardError; end

    class << self
      # Main entry point
      #
      # @param working_dir [String] The directory to operate in
      # @param github_token [String, nil] GitHub token for API requests
      # @param output [IO] Output stream for messages (default: $stdout)
      # @param dry_run [Boolean] If true, don't actually create PR (default: false)
      # @return [Hash] Result with :success, :new_versions, :pr_number, etc.
      def call(working_dir:, github_token: nil, output: $stdout, dry_run: false)
        new(
          working_dir: working_dir,
          github_token: github_token,
          output: output,
          dry_run: dry_run
        ).call
      end
    end

    attr_reader :working_dir, :github_token, :output, :dry_run

    def initialize(working_dir:, github_token: nil, output: $stdout, dry_run: false)
      @working_dir = working_dir
      @github_token = github_token
      @output = output
      @dry_run = dry_run
    end

    def call
      log_start

      new_versions = check_for_new_versions
      return success_no_versions if new_versions.empty?

      files_modified = add_versions(new_versions)
      return dry_run_result(new_versions, files_modified) if dry_run

      create_pull_request(new_versions, files_modified)
    rescue Error => e
      log("Error: #{e.message}", :red, emoji: :error)
      { success: false, error: e.message }
    end

    private

    def log_start
      log("Starting Ruby version check and PR creation...", :cyan, emoji: :start)
      log("")
    end

    def check_for_new_versions
      check_result = RubyVersionChecker.check(
        working_dir: working_dir,
        github_token: github_token,
        output: output
      )

      raise Error, check_result[:error] unless check_result[:success]

      check_result[:new_versions]
    end

    def success_no_versions
      log("")
      log("No new versions to add. Exiting.", :cyan, emoji: :skip)
      { success: true, new_versions: [], pr_created: false }
    end

    def dry_run_result(new_versions, files_modified)
      log("")
      log("Dry run mode - skipping PR creation", :yellow, emoji: :info)
      log("Would create PR for versions: #{new_versions.join(', ')}", emoji: :info)
      {
        success: true,
        new_versions: new_versions,
        files_modified: files_modified,
        pr_created: false,
        dry_run: true
      }
    end

    def create_pull_request(new_versions, files_modified)
      log_separator

      pr_result = RubyVersionPRCreator.call(
        new_versions,
        files_modified: files_modified,
        working_dir: working_dir,
        github_token: github_token,
        output: output
      )

      unless pr_result[:success]
        return {
          success: false,
          new_versions: new_versions,
          files_modified: files_modified,
          error: pr_result[:error]
        }
      end

      log_success(new_versions, pr_result)

      {
        success: true,
        new_versions: new_versions,
        files_modified: files_modified,
        pr_created: true,
        pr_number: pr_result[:pr_number],
        pr_url: pr_result[:pr_url]
      }
    end

    def log_separator
      log("")
      log("=" * 60)
      log("")
    end

    def log_success(new_versions, pr_result)
      log_separator
      log("All done!", :green, emoji: :party)
      log("")
      log("Summary:", :blue)
      log("  • New versions added: #{new_versions.join(', ')}")
      log("  • PR created: ##{pr_result[:pr_number]}")
      log("  • URL: #{pr_result[:pr_url]}")
    end

    # Add new versions using RubyVersionAdder (silent business logic)
    #
    # @param versions [Array<String>] List of versions to add
    # @return [Array<String>] List of files modified
    def add_versions(versions)
      log("")
      log("Adding #{versions.size} new version(s)...", :blue, emoji: :update)

      versions.each_with_object([]) do |version, files_modified|
        log("")
        log("Adding Ruby #{version}...", :magenta, emoji: :ruby)

        # Use RubyVersionAdder directly for silent operation
        add_result = RubyVersionAdder.call(version, working_dir: working_dir)

        if add_result[:success]
          files_modified.concat(add_result[:files_modified] || [])
          log_version_added(version, add_result)
        else
          log("Failed to add #{version}: #{add_result[:error]}", :red, emoji: :error)
        end
      end.uniq
    end

    def log_version_added(version, result)
      log("  Added #{version} to versions file", :green, emoji: :check)

      if result[:default_updated]
        log("  Updated default version to #{version}", :green, emoji: :check)
        log("  Bumped feature version to #{result[:new_feature_version]}", :green, emoji: :check)
      end
    end
  end
end
