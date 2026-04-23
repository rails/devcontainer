#!/usr/bin/env ruby
# frozen_string_literal: true

require "minitest/autorun"
require "open3"
require "rbconfig"
require "tempfile"

class NormalizePublishInputsScriptTest < Minitest::Test
  def test_reads_values_from_env_when_args_are_omitted
    output = Tempfile.new("github-output")

    status = run_script(
      {
        "RUBY_VERSIONS" => "3.3.1,3.2.4",
        "IMAGE_VERSIONS" => "ruby-1.1.0",
        "REPOSITORY" => "rails/devcontainer",
        "GITHUB_OUTPUT" => output.path
      }
    )

    assert status.success?
    assert_equal '["3.3.1","3.2.4"]', parse_output(output.path).fetch("ruby_versions_json")
  ensure
    output&.close!
  end

  def test_prefers_args_over_env_values
    output = Tempfile.new("github-output")

    status = run_script(
      {
        "RUBY_VERSIONS" => "3.0.0",
        "IMAGE_VERSIONS" => "ruby-1.1.0",
        "REPOSITORY" => "rails/devcontainer",
        "GITHUB_OUTPUT" => output.path
      },
      "--ruby-versions", "3.3.1",
      "--image-versions", "ruby-1.2.0",
      "--repository", "rails/devcontainer"
    )

    assert status.success?
    result = parse_output(output.path)
    assert_equal '["3.3.1"]', result.fetch("ruby_versions_json")
    assert_equal '["ruby-1.2.0"]', result.fetch("image_versions_json")
  ensure
    output&.close!
  end

  private

  def run_script(env, *args)
    _stdout, _stderr, status = Open3.capture3(
      env,
      RbConfig.ruby,
      script_path,
      *args,
      chdir: repo_root
    )
    status
  end

  def parse_output(path)
    File.read(path).lines.to_h do |line|
      key, value = line.strip.split("=", 2)
      [key, value]
    end
  end

  def script_path
    File.join(repo_root, "bin/normalize-publish-inputs")
  end

  def repo_root
    File.expand_path("../..", __dir__)
  end
end
