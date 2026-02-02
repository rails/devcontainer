#!/usr/bin/env ruby
# frozen_string_literal: true

require "minitest/autorun"
require "mocha/minitest"
require "json"
require "stringio"
require "webmock/minitest"
require_relative "../lib/ruby_version_pr_creator"

# Test suite for the RubyVersionPRCreator module
#
# These tests verify the behavior of the PR creator,
# which creates pull requests for new Ruby versions using Octokit.
# Git operations are mocked with Mocha for fast tests.
#
# Run with: ruby test/ruby_version_pr_creator_test.rb
class RubyVersionPRCreatorTest < Minitest::Test
  def setup
    @output = StringIO.new
    WebMock.disable_net_connect!
  end

  def teardown
    WebMock.reset!
  end

  def test_creates_pr_successfully
    stub_github_api_success
    creator = create_creator(["3.4.0"], [".github/ruby-versions.json"])
    stub_git_operations(creator)

    result = creator.call

    assert result[:success], "Should succeed: #{result[:error]}"
    assert_equal 123, result[:pr_number]
    assert_equal "https://github.com/rails/devcontainer/pull/123", result[:pr_url]
  end

  def test_creates_pr_with_multiple_versions
    stub_github_api_success
    creator = create_creator(["3.4.0", "3.3.5"], [".github/ruby-versions.json"])
    stub_git_operations(creator)

    result = creator.call

    assert result[:success]
    assert_equal 123, result[:pr_number]
  end

  def test_fails_without_github_token
    creator = create_creator(["3.4.0"], [".github/ruby-versions.json"], github_token: nil)

    result = creator.call

    refute result[:success]
    assert_match(/token required/i, result[:error])
  end

  def test_fails_with_invalid_token
    stub_github_api_unauthorized
    creator = create_creator(["3.4.0"], [".github/ruby-versions.json"])
    stub_git_operations(creator)

    result = creator.call

    refute result[:success]
    assert_match(/authentication failed/i, result[:error])
  end

  def test_closes_existing_automation_prs
    stub_github_api_with_existing_pr
    creator = create_creator(["3.4.0"], [".github/ruby-versions.json"])
    stub_git_operations(creator)

    result = creator.call

    assert result[:success]
    assert_match(/closing existing pr/i, @output.string)
  end

  def test_generates_correct_pr_title_single_version
    stub_github_api_success
    creator = create_creator(["3.4.0"], [".github/ruby-versions.json"])
    stub_git_operations(creator)

    creator.call

    assert_requested(:post, "https://api.github.com/repos/rails/devcontainer/pulls") do |req|
      body = JSON.parse(req.body)
      body["title"] == "Add Ruby version: 3.4.0"
    end
  end

  def test_generates_correct_pr_title_multiple_versions
    stub_github_api_success
    creator = create_creator(["3.4.0", "3.3.5"], [".github/ruby-versions.json"])
    stub_git_operations(creator)

    creator.call

    assert_requested(:post, "https://api.github.com/repos/rails/devcontainer/pulls") do |req|
      body = JSON.parse(req.body)
      body["title"] == "Add Ruby versions: 3.4.0, 3.3.5"
    end
  end

  def test_pr_body_contains_version_info
    stub_github_api_success
    creator = create_creator(["3.4.0"], [".github/ruby-versions.json"])
    stub_git_operations(creator)

    creator.call

    assert_requested(:post, "https://api.github.com/repos/rails/devcontainer/pulls") do |req|
      body = JSON.parse(req.body)
      body["body"].include?("3.4.0") &&
        body["body"].include?("ruby-build") &&
        body["body"].include?("Automated Ruby Version Update")
    end
  end

  def test_adds_labels_to_pr
    stub_github_api_success
    creator = create_creator(["3.4.0"], [".github/ruby-versions.json"])
    stub_git_operations(creator)

    creator.call

    assert_requested(:post, "https://api.github.com/repos/rails/devcontainer/issues/123/labels")
  end

  private

  def create_creator(versions, files, github_token: "test-token")
    RubyVersionPRCreator.new(
      versions,
      files_modified: files,
      working_dir: "/fake/dir",
      github_token: github_token,
      output: @output
    )
  end

  def stub_git_operations(creator)
    git_success = { stdout: "", stderr: "", success: true }

    creator.stubs(:run_git).with("--version", allow_failure: true).returns(
      { stdout: "git version 2.40.0", stderr: "", success: true }
    )
    creator.stubs(:run_git).with("config", "user.name", allow_failure: true).returns(
      { stdout: "Test User", stderr: "", success: true }
    )
    creator.stubs(:run_git).with("remote", "get-url", "origin").returns(
      { stdout: "https://github.com/rails/devcontainer.git", stderr: "", success: true }
    )
    creator.stubs(:run_git).with("fetch", "origin", "main", allow_failure: true).returns(git_success)
    creator.stubs(:run_git).with { |*args| args.first == "checkout" }.returns(git_success)
    creator.stubs(:run_git).with("add", ".").returns(git_success)
    creator.stubs(:run_git).with { |*args| args.first == "commit" }.returns(git_success)
    creator.stubs(:run_git).with { |*args| args.first == "push" }.returns(git_success)
  end

  def stub_github_api_success
    stub_request(:get, "https://api.github.com/user")
      .to_return(status: 200, body: JSON.generate({ login: "test-user" }), headers: json_headers)

    stub_request(:get, "https://api.github.com/repos/rails/devcontainer/pulls?state=open")
      .to_return(status: 200, body: JSON.generate([]), headers: json_headers)

    stub_request(:post, "https://api.github.com/repos/rails/devcontainer/pulls")
      .to_return(
        status: 201,
        body: JSON.generate({ number: 123, html_url: "https://github.com/rails/devcontainer/pull/123" }),
        headers: json_headers
      )

    stub_request(:post, "https://api.github.com/repos/rails/devcontainer/issues/123/labels")
      .to_return(status: 200, body: JSON.generate([]), headers: json_headers)
  end

  def stub_github_api_unauthorized
    stub_request(:get, "https://api.github.com/user").to_return(status: 401)
  end

  def stub_github_api_with_existing_pr
    stub_request(:get, "https://api.github.com/user")
      .to_return(status: 200, body: JSON.generate({ login: "test-user" }), headers: json_headers)

    stub_request(:get, "https://api.github.com/repos/rails/devcontainer/pulls?state=open")
      .to_return(
        status: 200,
        body: JSON.generate([{ number: 100, labels: [{ name: "automation" }, { name: "ruby-versions" }] }]),
        headers: json_headers
      )

    stub_request(:post, "https://api.github.com/repos/rails/devcontainer/issues/100/comments")
      .to_return(status: 201, body: JSON.generate({ id: 1 }), headers: json_headers)

    stub_request(:patch, "https://api.github.com/repos/rails/devcontainer/pulls/100")
      .to_return(status: 200, body: JSON.generate({ number: 100, state: "closed" }), headers: json_headers)

    stub_request(:post, "https://api.github.com/repos/rails/devcontainer/pulls")
      .to_return(
        status: 201,
        body: JSON.generate({ number: 123, html_url: "https://github.com/rails/devcontainer/pull/123" }),
        headers: json_headers
      )

    stub_request(:post, "https://api.github.com/repos/rails/devcontainer/issues/123/labels")
      .to_return(status: 200, body: JSON.generate([]), headers: json_headers)
  end

  def json_headers
    { "Content-Type" => "application/json" }
  end
end
