# frozen_string_literal: true

require_relative "../ruby_version_adder"
require_relative "../console"

module Commands
  # Add Ruby Version Command (Presentation Layer)
  #
  # This class provides a CLI-friendly interface for adding Ruby versions.
  # It wraps RubyVersionAdder with formatted output including colors and emojis.
  #
  # For silent/programmatic usage, use RubyVersionAdder directly.
  class AddRubyVersion
    include Console

    class << self
      # Main entry point for adding a Ruby version with formatted output
      #
      # @param version [String] The Ruby version to add (e.g., "3.4.0")
      # @param working_dir [String] The directory to operate in
      # @param output [IO] Output stream for messages (default: $stdout)
      # @return [Hash] Result with :success, :files_modified, and :message keys
      def call(version, working_dir:, output: $stdout)
        new(version, working_dir: working_dir, output: output).call
      end
    end

    attr_reader :version, :working_dir, :output

    def initialize(version, working_dir:, output: $stdout)
      @version = version
      @working_dir = working_dir
      @output = output
    end

    def call
      log_checking_configuration

      # Get current default before running the service
      adder = RubyVersionAdder.new(version, working_dir: working_dir)

      begin
        current_default = adder.current_default_version
        log_version_info(current_default)
      rescue RubyVersionAdder::Error
        # Will be handled by the service call
      end

      # Call the business logic service
      result = adder.call

      if result[:success]
        log_success_result(result)
      else
        log_error(result[:error])
      end

      result
    end

    private

    def log_checking_configuration
      log("Checking current configuration...", :cyan, emoji: :search)
    end

    def log_version_info(current_default)
      log("Current default version: #{current_default}")
      log("New version to add: #{version}")
    end

    def log_success_result(result)
      log("")
      log("Adding #{version} to #{RubyVersionAdder::VERSIONS_JSON_FILE}...", :blue, emoji: :edit)
      log("Successfully added to #{RubyVersionAdder::VERSIONS_JSON_FILE}", :green, emoji: :check)

      if result[:default_updated]
        log_default_updated(result)
      else
        log_default_unchanged(result[:previous_default])
      end

      log_final_success(result[:files_modified])
    end

    def log_default_updated(result)
      log("")
      log("New version #{version} is newer than current default #{result[:previous_default]}", :yellow, emoji: :update)
      log("Updated default version to #{version}", :green, emoji: :check)
      log("Updated README default version to #{version}", :green, emoji: :check)

      log("")
      log("Bumping feature version...", :yellow, emoji: :update)
      log("Feature version bumped from #{result[:old_feature_version]} to #{result[:new_feature_version]}", :green, emoji: :check)

      log("")
      log("Updating test files...", :blue, emoji: :edit)
      RubyVersionAdder::TEST_FILES.each do |test_file|
        log("Updated #{test_file}", :green, emoji: :check)
      end
    end

    def log_default_unchanged(previous_default)
      log("")
      log("New version #{version} is not newer than current default #{previous_default}", :cyan, emoji: :info)
      log("Default version remains unchanged")
      log("")
      log("Skipping test file updates (new version #{version} is not newer than current default #{previous_default})", :cyan, emoji: :info)
    end

    def log_final_success(files_modified)
      log("")
      log("Successfully added Ruby version #{version}!", :green, emoji: :party)
      log("")
      log("Files modified:", :blue, emoji: :file)
      files_modified.each { |file| log("  • #{file}") }

      log("")
      log("Next steps:", :magenta, emoji: :bulb)
      log("  1. Review the changes: git diff")
      log("  2. Commit the changes: git add . && git commit -m 'Add Ruby #{version}'")
      log("  3. Push changes: git push")
    end

    def log_error(error_message)
      log("Error: #{error_message}", :red, emoji: :error)
    end
  end
end
