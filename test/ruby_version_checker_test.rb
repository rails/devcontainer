#!/usr/bin/env ruby
# frozen_string_literal: true

require "minitest/autorun"
require "fileutils"
require "json"
require "tempfile"
require "stringio"
require "webmock/minitest"
require_relative "../lib/ruby_version_checker"

# Test suite for the RubyVersionChecker module
#
# These tests verify the behavior of the Ruby version checker,
# which fetches available versions from ruby-build and compares
# them with the current versions in the repository.
#
# Run with: ruby test/ruby_version_checker_test.rb
class RubyVersionCheckerTest < Minitest::Test
  def setup
    @temp_dir = Dir.mktmpdir("ruby-version-checker-test")
    @output = StringIO.new

    # Create the directory structure
    FileUtils.mkdir_p(File.join(@temp_dir, ".github"))

    # Disable real network connections
    WebMock.disable_net_connect!
  end

  def teardown
    FileUtils.rm_rf(@temp_dir)
    WebMock.reset!
  end

  def test_check_returns_new_versions
    setup_versions_file(["3.3.0", "3.2.0"])
    stub_github_api(available_versions: ["3.4.0", "3.3.0", "3.2.0"])

    result = RubyVersionChecker.check(
      working_dir: @temp_dir,
      github_token: "test-token",
      output: @output
    )

    assert result[:success]
    assert_equal ["3.4.0"], result[:new_versions]
  end

  def test_check_returns_empty_when_up_to_date
    setup_versions_file(["3.4.0", "3.3.0", "3.2.0"])
    stub_github_api(available_versions: ["3.4.0", "3.3.0", "3.2.0"])

    result = RubyVersionChecker.check(
      working_dir: @temp_dir,
      github_token: "test-token",
      output: @output
    )

    assert result[:success]
    assert_empty result[:new_versions]
  end

  def test_check_filters_out_non_stable_versions
    setup_versions_file(["3.3.0"])
    stub_github_api(available_versions: ["3.4.0-preview1", "3.4.0", "3.3.0", "3.3.0-rc1"])

    result = RubyVersionChecker.check(
      working_dir: @temp_dir,
      github_token: "test-token",
      output: @output
    )

    assert result[:success]
    # Only 3.4.0 should be returned (stable version, not already in config)
    assert_equal ["3.4.0"], result[:new_versions]
  end

  def test_check_filters_versions_below_minimum
    setup_versions_file(["3.3.0"])
    stub_github_api(available_versions: ["3.4.0", "3.3.0", "3.1.0", "3.0.0", "2.7.0"])

    result = RubyVersionChecker.check(
      working_dir: @temp_dir,
      github_token: "test-token",
      output: @output
    )

    assert result[:success]
    # Only 3.4.0 should be returned (>= 3.2.0 and not already in config)
    assert_equal ["3.4.0"], result[:new_versions]
  end

  def test_check_sorts_versions_descending
    setup_versions_file(["3.2.0"])
    stub_github_api(available_versions: ["3.3.0", "3.4.0", "3.2.5", "3.2.0"])

    result = RubyVersionChecker.check(
      working_dir: @temp_dir,
      github_token: "test-token",
      output: @output
    )

    assert result[:success]
    assert_equal ["3.4.0", "3.3.0", "3.2.5"], result[:new_versions]
  end

  def test_check_fails_when_versions_file_missing
    # Don't create the versions file
    stub_github_api(available_versions: ["3.4.0"])

    result = RubyVersionChecker.check(
      working_dir: @temp_dir,
      github_token: "test-token",
      output: @output
    )

    refute result[:success]
    assert_match(/not found/i, result[:error])
  end

  def test_check_fails_on_api_error
    setup_versions_file(["3.3.0"])
    stub_github_api_error(status: 401)

    result = RubyVersionChecker.check(
      working_dir: @temp_dir,
      github_token: "invalid-token",
      output: @output
    )

    refute result[:success]
    assert_match(/authentication failed/i, result[:error])
  end

  def test_check_handles_rate_limit
    setup_versions_file(["3.3.0"])
    stub_github_api_error(status: 403)

    result = RubyVersionChecker.check(
      working_dir: @temp_dir,
      github_token: "test-token",
      output: @output
    )

    refute result[:success]
    assert_match(/rate limit/i, result[:error])
  end

  private

  def setup_versions_file(versions)
    path = File.join(@temp_dir, ".github/ruby-versions.json")
    File.write(path, JSON.pretty_generate(versions))
  end

  def stub_github_api(available_versions:)
    # Stub the releases/latest endpoint
    stub_request(:get, "https://api.github.com/repos/rbenv/ruby-build/releases/latest")
      .to_return(
        status: 200,
        body: JSON.generate({ tag_name: "v20240101" }),
        headers: { "Content-Type" => "application/json" }
      )

    # Stub the contents endpoint
    contents = available_versions.map { |v| { "name" => v } }
    stub_request(:get, "https://api.github.com/repos/rbenv/ruby-build/contents/share/ruby-build?ref=v20240101")
      .to_return(
        status: 200,
        body: JSON.generate(contents),
        headers: { "Content-Type" => "application/json" }
      )
  end

  def stub_github_api_error(status:)
    stub_request(:get, "https://api.github.com/repos/rbenv/ruby-build/releases/latest")
      .to_return(status: status, body: "", headers: {})
  end
end
