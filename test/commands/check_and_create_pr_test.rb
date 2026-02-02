#!/usr/bin/env ruby
# frozen_string_literal: true

require "minitest/autorun"
require "mocha/minitest"
require "stringio"
require_relative "../../lib/commands/check_and_create_pr"

# Test suite for the Commands::CheckAndCreatePR module
#
# These tests verify the orchestration of the Ruby version check
# and PR creation workflow. All external dependencies (RubyVersionChecker
# and RubyVersionPRCreator) are mocked to ensure isolated unit tests.
#
# Run with: ruby test/commands/check_and_create_pr_test.rb
class Commands::CheckAndCreatePRTest < Minitest::Test
  def setup
    @output = StringIO.new
    @working_dir = "/test/working/dir"
    @github_token = "test-token"
  end

  # ==========================================================================
  # Core Workflow Tests
  # ==========================================================================

  def test_call_creates_pr_when_new_versions_found
    stub_version_checker_with_new_versions(["3.4.0"])
    stub_pr_creator_success(pr_number: 123, pr_url: "https://github.com/rails/devcontainer/pull/123")

    result = Commands::CheckAndCreatePR.call(
      working_dir: @working_dir,
      github_token: @github_token,
      output: @output
    )

    assert result[:success]
    assert_equal ["3.4.0"], result[:new_versions]
    assert result[:pr_created]
    assert_equal 123, result[:pr_number]
  end

  def test_call_returns_success_when_no_new_versions
    stub_version_checker_with_no_new_versions

    result = Commands::CheckAndCreatePR.call(
      working_dir: @working_dir,
      github_token: @github_token,
      output: @output
    )

    assert result[:success]
    assert_empty result[:new_versions]
    refute result[:pr_created]
  end

  def test_call_skips_pr_creation_in_dry_run_mode
    stub_version_checker_with_new_versions(["3.4.0"])
    RubyVersionPRCreator.expects(:call).never

    result = Commands::CheckAndCreatePR.call(
      working_dir: @working_dir,
      github_token: @github_token,
      output: @output,
      dry_run: true
    )

    assert result[:success]
    assert result[:dry_run]
    refute result[:pr_created]
  end

  def test_call_returns_error_when_version_check_fails
    stub_version_checker_failure("Failed to fetch versions")

    result = Commands::CheckAndCreatePR.call(
      working_dir: @working_dir,
      github_token: @github_token,
      output: @output
    )

    refute result[:success]
    assert_equal "Failed to fetch versions", result[:error]
  end

  # ==========================================================================
  # Presentation Tests (Output Format)
  # ==========================================================================

  def test_output_shows_start_message
    stub_version_checker_with_no_new_versions

    Commands::CheckAndCreatePR.call(
      working_dir: @working_dir,
      github_token: @github_token,
      output: @output
    )

    assert_match(/Starting Ruby version check/, @output.string)
  end

  def test_output_shows_no_versions_message
    stub_version_checker_with_no_new_versions

    Commands::CheckAndCreatePR.call(
      working_dir: @working_dir,
      github_token: @github_token,
      output: @output
    )

    assert_match(/No new versions to add/, @output.string)
  end

  def test_output_shows_dry_run_message
    stub_version_checker_with_new_versions(["3.4.0"])

    Commands::CheckAndCreatePR.call(
      working_dir: @working_dir,
      github_token: @github_token,
      output: @output,
      dry_run: true
    )

    assert_match(/Dry run mode/, @output.string)
    assert_match(/Would create PR for versions: 3.4.0/, @output.string)
  end

  def test_output_shows_success_summary
    stub_version_checker_with_new_versions(["3.4.0"])
    stub_pr_creator_success(pr_number: 123, pr_url: "https://github.com/rails/devcontainer/pull/123")

    Commands::CheckAndCreatePR.call(
      working_dir: @working_dir,
      github_token: @github_token,
      output: @output
    )

    assert_match(/All done!/, @output.string)
    assert_match(/New versions added: 3.4.0/, @output.string)
    assert_match(/PR created: #123/, @output.string)
  end

  def test_output_shows_adding_versions_progress
    stub_version_checker_with_new_versions(["3.4.0"])
    stub_pr_creator_success(pr_number: 123)

    Commands::CheckAndCreatePR.call(
      working_dir: @working_dir,
      github_token: @github_token,
      output: @output
    )

    assert_match(/Adding 1 new version/, @output.string)
    assert_match(/Adding Ruby 3.4.0/, @output.string)
  end

  # ==========================================================================
  # Integration Tests
  # ==========================================================================

  def test_call_uses_ruby_version_adder_for_each_version
    stub_version_checker_with_new_versions(["3.4.0", "3.3.1"])

    RubyVersionAdder.expects(:call).with("3.4.0", working_dir: @working_dir).returns({
      success: true,
      files_modified: [".github/ruby-versions.json"],
      default_updated: false
    })
    RubyVersionAdder.expects(:call).with("3.3.1", working_dir: @working_dir).returns({
      success: true,
      files_modified: [".github/ruby-versions.json"],
      default_updated: false
    })
    stub_pr_creator_success(pr_number: 123)

    result = Commands::CheckAndCreatePR.call(
      working_dir: @working_dir,
      github_token: @github_token,
      output: @output
    )

    assert result[:success]
  end

  private

  def stub_version_checker_with_new_versions(versions)
    RubyVersionChecker.stubs(:check).returns({
      success: true,
      new_versions: versions,
      current_versions: ["3.3.0"]
    })
    stub_ruby_version_adder
  end

  def stub_version_checker_with_no_new_versions
    RubyVersionChecker.stubs(:check).returns({
      success: true,
      new_versions: [],
      current_versions: ["3.3.0"]
    })
  end

  def stub_version_checker_failure(error_message)
    RubyVersionChecker.stubs(:check).returns({
      success: false,
      error: error_message
    })
  end

  def stub_ruby_version_adder(files_modified: nil)
    files_modified ||= [".github/ruby-versions.json", "features/src/ruby/README.md"]
    RubyVersionAdder.stubs(:call).returns({
      success: true,
      files_modified: files_modified,
      default_updated: false
    })
  end

  def stub_pr_creator_success(pr_number:, pr_url: nil)
    pr_url ||= "https://github.com/rails/devcontainer/pull/#{pr_number}"
    RubyVersionPRCreator.stubs(:call).returns({
      success: true,
      pr_number: pr_number,
      pr_url: pr_url
    })
  end
end
