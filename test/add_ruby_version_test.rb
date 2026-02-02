#!/usr/bin/env ruby
# frozen_string_literal: true

require "minitest/autorun"
require "fileutils"
require "json"
require "tempfile"
require "stringio"
require_relative "../lib/add_ruby_version"

# Test suite for the add-ruby-version script
#
# These tests verify the behavior of the Ruby version management script,
# which automates adding new Ruby versions to the devcontainer configuration.
#
# Run with: ruby test/add_ruby_version_test.rb
# Or:       bundle exec ruby test/add_ruby_version_test.rb
class AddRubyVersionTest < Minitest::Test
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

  def test_rejects_invalid_version_format_no_dots
    setup_valid_environment
    result = run_script("330")

    refute result[:success], "Should fail for version without dots"
    assert_match(/invalid version format/i, result[:output])
  end

  def test_rejects_invalid_version_format_two_parts
    setup_valid_environment
    result = run_script("3.3")

    refute result[:success], "Should fail for version with only two parts"
    assert_match(/invalid version format/i, result[:output])
  end

  def test_rejects_invalid_version_format_four_parts
    setup_valid_environment
    result = run_script("3.3.0.1")

    refute result[:success], "Should fail for version with four parts"
    assert_match(/invalid version format/i, result[:output])
  end

  def test_rejects_invalid_version_format_with_letters
    setup_valid_environment
    result = run_script("3.3.0-preview1")

    refute result[:success], "Should fail for version with letters"
    assert_match(/invalid version format/i, result[:output])
  end

  def test_accepts_valid_version_format
    setup_valid_environment
    result = run_script("3.4.0")

    assert result[:success], "Should accept valid x.y.z format: #{result[:output]}"
  end

  def test_rejects_duplicate_version
    setup_valid_environment(versions: ["3.3.0", "3.2.0"])
    result = run_script("3.3.0")

    refute result[:success], "Should fail when version already exists"
    assert_match(/already exists/i, result[:output])
  end

  def test_accepts_new_version
    setup_valid_environment(versions: ["3.3.0", "3.2.0"])
    result = run_script("3.4.0")

    assert result[:success], "Should accept new version: #{result[:output]}"
  end

  def test_adds_version_to_json_file
    setup_valid_environment(versions: ["3.3.0", "3.2.0"])
    run_script("3.4.0")

    versions = read_versions_json
    assert_includes versions, "3.4.0", "New version should be added to JSON"
    assert_includes versions, "3.3.0", "Existing versions should be preserved"
    assert_includes versions, "3.2.0", "Existing versions should be preserved"

    content = File.read(File.join(@temp_dir, ".github/ruby-versions.json"))
    assert_match(/^    "3\.4\.0"/, content, "Should use 4-space indentation")
  end

  def test_sorts_versions_descending
    setup_valid_environment(versions: ["3.3.0", "3.2.0"])
    run_script("3.4.0")

    versions = read_versions_json
    assert_equal ["3.4.0", "3.3.0", "3.2.0"], versions, "Versions should be sorted descending"
  end

  def test_sorts_versions_with_double_digit_patch
    setup_valid_environment(versions: ["3.3.10", "3.3.9", "3.3.0"])
    run_script("3.3.11")

    versions = read_versions_json
    assert_equal ["3.3.11", "3.3.10", "3.3.9", "3.3.0"], versions,
      "Versions should be sorted correctly with double-digit patch numbers"
  end

  def test_adds_older_version_in_correct_position
    setup_valid_environment(versions: ["3.3.0", "3.1.0"])
    run_script("3.2.0")

    versions = read_versions_json
    assert_equal ["3.3.0", "3.2.0", "3.1.0"], versions,
      "Older version should be inserted in correct sorted position"
  end

  def test_updates_default_when_version_is_newer
    setup_valid_environment(versions: ["3.3.0", "3.2.0"], default_ruby: "3.3.0")
    run_script("3.4.0")

    feature = read_feature_json
    assert_equal "3.4.0", feature["options"]["version"]["default"],
      "Default should be updated to newer version"
  end

  def test_does_not_update_default_when_version_is_older
    setup_valid_environment(versions: ["3.3.0", "3.2.0"], default_ruby: "3.3.0")
    run_script("3.2.5")

    feature = read_feature_json
    assert_equal "3.3.0", feature["options"]["version"]["default"],
      "Default should remain unchanged for older version"
  end

  def test_does_not_update_default_when_version_is_same_minor
    setup_valid_environment(versions: ["3.3.0"], default_ruby: "3.3.0")
    run_script("3.3.1")

    feature = read_feature_json
    assert_equal "3.3.1", feature["options"]["version"]["default"],
      "Default should be updated for newer patch version"
  end

  def test_updates_readme_when_version_is_newer
    setup_valid_environment(default_ruby: "3.3.0")
    run_script("3.4.0")

    readme = read_readme
    assert_match(/\| string \| 3\.4\.0 \|/, readme,
      "README should show new default version")
    refute_match(/\| string \| 3\.3\.0 \|/, readme,
      "README should not show old default version")
  end

  def test_does_not_update_readme_when_version_is_older
    setup_valid_environment(default_ruby: "3.3.0")
    run_script("3.2.5")

    readme = read_readme
    assert_match(/\| string \| 3\.3\.0 \|/, readme,
      "README should keep old default version")
  end

  def test_bumps_feature_version_when_default_changes
    setup_valid_environment(feature_version: "2.0.0", default_ruby: "3.3.0")
    run_script("3.4.0")

    feature = read_feature_json
    assert_equal "2.0.1", feature["version"],
      "Feature version should be bumped when default changes"

    content = File.read(File.join(@temp_dir, "features/src/ruby/devcontainer-feature.json"))
    assert_match(/^    "id"/, content, "Should use 4-space indentation")
  end

  def test_does_not_bump_feature_version_when_default_unchanged
    setup_valid_environment(feature_version: "2.0.0", default_ruby: "3.3.0")
    run_script("3.2.5")

    feature = read_feature_json
    assert_equal "2.0.0", feature["version"],
      "Feature version should not change when default is unchanged"
  end

  def test_bumps_feature_version_patch_correctly
    setup_valid_environment(feature_version: "2.1.9", default_ruby: "3.3.0")
    run_script("3.4.0")

    feature = read_feature_json
    assert_equal "2.1.10", feature["version"],
      "Feature version patch should increment correctly"
  end

  def test_updates_test_files_when_default_changes
    setup_valid_environment(default_ruby: "3.3.0")
    run_script("3.4.0")

    test_content = read_test_file("test.sh")
    assert_match(/3\.4\.0/, test_content, "test.sh should contain new version")

    rbenv_content = read_test_file("with_rbenv.sh")
    assert_match(/3\.4\.0/, rbenv_content, "with_rbenv.sh should contain new version")
  end

  def test_does_not_update_test_files_when_default_unchanged
    setup_valid_environment(default_ruby: "3.3.0")
    run_script("3.2.5")

    test_content = read_test_file("test.sh")
    assert_match(/3\.3\.0/, test_content, "test.sh should keep old version")
    refute_match(/3\.2\.5/, test_content, "test.sh should not contain older version")
  end

  def test_output_shows_success_message
    setup_valid_environment
    result = run_script("3.4.0")

    assert_match(/successfully added/i, result[:output])
    assert_match(/3\.4\.0/, result[:output])
  end

  def test_output_lists_modified_files
    setup_valid_environment(default_ruby: "3.3.0")
    result = run_script("3.4.0")

    assert_match(/ruby-versions\.json/i, result[:output])
    assert_match(/devcontainer-feature\.json/i, result[:output])
    assert_match(/README\.md/i, result[:output])
  end

  def test_output_shows_version_comparison
    setup_valid_environment(default_ruby: "3.3.0")
    result = run_script("3.4.0")

    assert_match(/current default.*3\.3\.0/i, result[:output])
    assert_match(/new version.*3\.4\.0/i, result[:output])
  end

  def test_output_indicates_skipped_updates_for_older_version
    setup_valid_environment(default_ruby: "3.3.0")
    result = run_script("3.2.5")

    assert_match(/not newer than current default/i, result[:output])
    assert_match(/skipping/i, result[:output])
  end

  def test_fails_when_versions_json_missing
    setup_valid_environment
    FileUtils.rm(File.join(@temp_dir, ".github/ruby-versions.json"))
    result = run_script("3.4.0")

    refute result[:success], "Should fail when versions JSON is missing"
    assert_match(/not found/i, result[:output])
  end

  def test_fails_when_feature_json_missing
    setup_valid_environment
    FileUtils.rm(File.join(@temp_dir, "features/src/ruby/devcontainer-feature.json"))
    result = run_script("3.4.0")

    refute result[:success], "Should fail when feature JSON is missing"
    assert_match(/not found/i, result[:output])
  end

  def test_fails_when_readme_missing
    setup_valid_environment
    FileUtils.rm(File.join(@temp_dir, "features/src/ruby/README.md"))
    result = run_script("3.4.0")

    refute result[:success], "Should fail when README is missing"
    assert_match(/not found/i, result[:output])
  end

  def test_fails_when_test_file_missing
    setup_valid_environment
    FileUtils.rm(File.join(@temp_dir, "features/test/ruby/test.sh"))
    result = run_script("3.4.0")

    refute result[:success], "Should fail when test file is missing"
    assert_match(/not found/i, result[:output])
  end

  def test_handles_empty_versions_array
    setup_valid_environment(versions: [])
    result = run_script("3.4.0")

    assert result[:success], "Should handle empty versions array: #{result[:output]}"
    versions = read_versions_json
    assert_equal ["3.4.0"], versions
  end

  def test_handles_major_version_change
    setup_valid_environment(versions: ["3.3.0"], default_ruby: "3.3.0")
    run_script("4.0.0")

    feature = read_feature_json
    assert_equal "4.0.0", feature["options"]["version"]["default"],
      "Should handle major version upgrades"
  end

  def test_preserves_other_feature_json_fields
    setup_valid_environment
    run_script("3.4.0")

    feature = read_feature_json
    assert_equal "ruby", feature["id"], "Should preserve id field"
    assert_equal "Ruby", feature["name"], "Should preserve name field"
    assert_equal "Installs Ruby", feature["description"], "Should preserve description"
  end

  private

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

  def read_readme
    File.read(File.join(@temp_dir, "features/src/ruby/README.md"))
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

  def read_test_file(filename)
    File.read(File.join(@temp_dir, "features/test/ruby/#{filename}"))
  end

  def run_script(version)
    output = StringIO.new
    result = AddRubyVersion.call(version, working_dir: @temp_dir, output: output)
    { output: output.string, success: result[:success] }
  end

  def setup_valid_environment(versions: ["3.3.0", "3.2.0"], default_ruby: "3.3.0", feature_version: "2.0.0")
    create_versions_json(versions)
    create_feature_json(version: feature_version, default_ruby: default_ruby)
    create_readme(default_version: default_ruby)
    create_test_file("test.sh", version: default_ruby)
    create_test_file("with_rbenv.sh", version: default_ruby)
  end
end
