# frozen_string_literal: true

require "fileutils"
require "json"
require "minitest/autorun"
require "open3"
require "rbconfig"
require "tmpdir"

class PublishRubyUpdatesScriptTest < Minitest::Test
  ROOT = File.expand_path("../..", __dir__)
  SCRIPT = File.join(ROOT, "bin/publish-ruby-updates")
  TOKEN = "test-token-for-publish-ruby-updates"

  def setup
    @dir = Dir.mktmpdir("publish-ruby-updates-cli")
    git("init", "--quiet")
    git("config", "--local", "user.name", "Release Test")
    git("config", "--local", "user.email", "release@example.test")
    FileUtils.mkdir_p(File.join(@dir, ".github"))
    FileUtils.mkdir_p(File.join(@dir, "features/src/ruby"))
    File.write(File.join(@dir, ".github/ruby-versions.json"), '["4.0.10","3.4.13","3.3.14"]')
    File.write(File.join(@dir, "features/src/ruby/devcontainer-feature.json"), '{"version":"2.2.7"}')
    git("add", "--all")
    git("commit", "--quiet", "--no-gpg-sign", "-m", "Fixture snapshot")
    @sha = git("rev-parse", "HEAD")
  end

  def teardown
    FileUtils.remove_entry(@dir)
  end

  def test_reads_environment_and_writes_github_output_and_a_preview_summary
    output = File.join(@dir, "github-output")
    summary = File.join(@dir, "github-summary")
    File.write(summary, "Existing summary\n")
    stdout, stderr, status = run_script(
      "--dry-run",
      REPOSITORY: "rails/devcontainer", GITHUB_OUTPUT: output, GITHUB_STEP_SUMMARY: summary
    )

    assert status.success?, stderr
    assert_empty stdout
    assert_equal({
      "mode" => "none", "ruby_versions_json" => "[]", "image_tag" => "", "source_sha" => @sha, "create_tag" => "false"
    }, File.readlines(output, chomp: true).to_h { |line| line.split("=", 2) })
    contents = File.read(summary)
    assert_match(/\AExisting summary\n/, contents)
    assert_match(/preview/i, contents)
    assert_includes contents, @sha
    refute_includes contents, TOKEN
  end

  def test_prints_json_with_options_that_override_environment_values
    stdout, stderr, status = run_script(
      "--before-ref", "HEAD", "--after-ref", @sha, "--repository", "rails/devcontainer",
      "--working-dir", @dir, "--dry-run",
      cwd: ROOT, BEFORE_SHA: "missing-before", AFTER_SHA: "missing-after", REPOSITORY: ""
    )

    assert status.success?, stderr
    assert_equal({
      "mode" => "none", "ruby_versions" => [], "image_tag" => nil, "source_sha" => @sha, "create_tag" => false
    }, JSON.parse(stdout))
  end

  def test_accepts_github_repository_as_the_fallback
    stdout, stderr, status = run_script("--dry-run")

    assert status.success?, stderr
    assert_equal "none", JSON.parse(stdout).fetch("mode")
  end

  def test_invalid_refs_fail_without_output_or_github_requests
    output = File.join(@dir, "github-output")
    summary = File.join(@dir, "github-summary")
    stdout, stderr, status = run_script(
      AFTER_SHA: "0" * 40, GITHUB_OUTPUT: output, GITHUB_STEP_SUMMARY: summary
    )

    assert_equal 1, status.exitstatus
    assert_empty stdout
    refute_empty stderr
    refute_includes stderr, "WebMock::NetConnectNotAllowedError"
    refute_includes stderr, TOKEN
    refute_path_exists output
    refute_path_exists summary
  end

  private

  def git(*args)
    stdout, stderr, status = Open3.capture3("git", *args, chdir: @dir)
    raise "git #{args.first} failed: #{stderr}" unless status.success?

    stdout.strip
  end

  def run_script(*args, cwd: @dir, **overrides)
    env = {
      "BEFORE_SHA" => @sha, "AFTER_SHA" => @sha, "REPOSITORY" => nil, "GITHUB_REPOSITORY" => "rails/devcontainer",
      "GITHUB_OUTPUT" => nil, "GITHUB_STEP_SUMMARY" => nil, "GITHUB_TOKEN" => TOKEN,
      "BUNDLE_GEMFILE" => File.join(ROOT, "Gemfile"), "GIT_ALLOW_PROTOCOL" => "file"
    }.merge(overrides.transform_keys(&:to_s))
    Open3.capture3(
      env, RbConfig.ruby, "-rbundler/setup", "-rwebmock", "-e", "WebMock.disable_net_connect!; load ARGV.shift",
      "--", SCRIPT, *args, chdir: cwd
    )
  end
end
