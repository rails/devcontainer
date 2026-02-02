#!/usr/bin/env ruby
# frozen_string_literal: true

require "minitest/autorun"
require "fileutils"
require "json"
require "tempfile"
require "stringio"
require_relative "../../lib/commands/add_ruby_version"

# Test suite for the Commands::AddRubyVersion command
#
# These tests verify the behavior of the Ruby version management command,
# which automates adding new Ruby versions to the devcontainer configuration.
#
# Run with: ruby test/commands/add_ruby_version_test.rb
class Commands::AddRubyVersionTest < Minitest::Test
  def setup
    @temp_dir = Dir.mktmpdir("add-ruby-version-test")

    # Create the directory structure
    FileUtils.mkdir_p(File.join(@temp_dir, ".github"))
    FileUtils.mkdir_p(File.join(@temp_dir, "features/src/ruby"))
    FileUtils.mkdir_p(File.join(@temp_dir, "features/test/ruby"))
  end

  def teardown
    FileUtils.rm_rf(@temp_dir)
  end

  # ==========================================================================
  # Presentation Tests (Output Format)
  # ==========================================================================

  def test_output_shows_success_message
    setup_valid_environment
    result = run_command("3.4.0")

    assert_match(/successfully added/i, result[:output])
    assert_match(/3\.4\.0/, result[:output])
  end

  def test_output_lists_modified_files
    setup_valid_environment(default_ruby: "3.3.0")
    result = run_command("3.4.0")

    assert_match(/ruby-versions\.json/i, result[:output])
    assert_match(/devcontainer-feature\.json/i, result[:output])
    assert_match(/README\.md/i, result[:output])
  end

  def test_output_shows_version_comparison
    setup_valid_environment(default_ruby: "3.3.0")
    result = run_command("3.4.0")

    assert_match(/current default.*3\.3\.0/i, result[:output])
    assert_match(/new version.*3\.4\.0/i, result[:output])
  end

  def test_output_indicates_skipped_updates_for_older_version
    setup_valid_environment(default_ruby: "3.3.0")
    result = run_command("3.2.5")

    assert_match(/not newer than current default/i, result[:output])
    assert_match(/skipping/i, result[:output])
  end

  def test_output_shows_checking_configuration
    setup_valid_environment
    result = run_command("3.4.0")

    assert_match(/checking current configuration/i, result[:output])
  end

  def test_output_shows_next_steps
    setup_valid_environment
    result = run_command("3.4.0")

    assert_match(/next steps/i, result[:output])
    assert_match(/git diff/i, result[:output])
    assert_match(/git.*commit/i, result[:output])
  end

  def test_output_shows_feature_version_bump
    setup_valid_environment(default_ruby: "3.3.0", feature_version: "2.0.0")
    result = run_command("3.4.0")

    assert_match(/bumping feature version/i, result[:output])
    assert_match(/2\.0\.0.*2\.0\.1/i, result[:output])
  end

  def test_output_shows_error_for_invalid_version
    setup_valid_environment
    result = run_command("invalid")

    assert_match(/error/i, result[:output])
    assert_match(/invalid version format/i, result[:output])
  end

  def test_output_shows_error_for_missing_file
    setup_valid_environment
    FileUtils.rm(File.join(@temp_dir, ".github/ruby-versions.json"))
    result = run_command("3.4.0")

    assert_match(/error/i, result[:output])
    assert_match(/not found/i, result[:output])
  end

  # ==========================================================================
  # Integration Tests (Verifies underlying service is called)
  # ==========================================================================

  def test_delegates_to_ruby_version_adder
    setup_valid_environment(versions: ["3.3.0"])
    result = run_command("3.4.0")

    assert result[:success]
    versions = read_versions_json
    assert_includes versions, "3.4.0"
  end

  def test_returns_files_modified
    setup_valid_environment(versions: ["3.3.0"], default_ruby: "3.3.0")
    result = run_command("3.4.0")

    assert result[:success]
    assert_includes result[:files_modified], ".github/ruby-versions.json"
  end

  def test_returns_default_updated_metadata
    setup_valid_environment(versions: ["3.3.0"], default_ruby: "3.3.0")
    result = run_command("3.4.0")

    assert result[:success]
    assert result[:default_updated]
  end

  private

  def run_command(version)
    output = StringIO.new
    result = Commands::AddRubyVersion.call(version, working_dir: @temp_dir, output: output)
    result.merge(output: output.string)
  end

  def create_versions_json(versions)
    File.write(File.join(@temp_dir, ".github/ruby-versions.json"), JSON.pretty_generate(versions) + "\n")
  end

  def read_versions_json
    JSON.parse(File.read(File.join(@temp_dir, ".github/ruby-versions.json")))
  end

  def create_feature_json(version: "2.0.0", default_ruby: "3.3.0")
    data = {
      "id" => "ruby",
      "version" => version,
      "name" => "Ruby",
      "description" => "Installs Ruby",
      "options" => {
        "version" => {
          "type" => "string",
          "default" => default_ruby,
          "description" => "The ruby version to be installed"
        }
      }
    }
    File.write(File.join(@temp_dir, "features/src/ruby/devcontainer-feature.json"), JSON.pretty_generate(data) + "\n")
  end

  def read_feature_json
    JSON.parse(File.read(File.join(@temp_dir, "features/src/ruby/devcontainer-feature.json")))
  end

  def create_readme(default_version: "3.3.0")
    content = <<~README
      # Ruby

      Installs Ruby and a version manager.

      ## Options

      | Options Id | Description | Type | Default Value |
      |-----|-----|-----|-----|
      | version | The version of ruby to be installed | string | #{default_version} |
      | versionManager | The version manager to use | string | mise |
    README
    File.write(File.join(@temp_dir, "features/src/ruby/README.md"), content)
  end

  def create_test_file(filename, version: "3.3.0")
    content = <<~BASH
      #!/bin/bash
      set -e
      check "Ruby version is set to #{version}" bash -c "ruby -v | grep #{version}"
      reportResults
    BASH
    File.write(File.join(@temp_dir, "features/test/ruby/#{filename}"), content)
  end

  def setup_valid_environment(versions: ["3.3.0", "3.2.0"], default_ruby: "3.3.0", feature_version: "2.0.0")
    create_versions_json(versions)
    create_feature_json(version: feature_version, default_ruby: default_ruby)
    create_readme(default_version: default_ruby)
    create_test_file("test.sh", version: default_ruby)
    create_test_file("with_rbenv.sh", version: default_ruby)
  end
end
