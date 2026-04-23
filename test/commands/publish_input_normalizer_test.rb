#!/usr/bin/env ruby
# frozen_string_literal: true

require "minitest/autorun"
require_relative "../../lib/commands/publish_input_normalizer"

class Commands::PublishInputNormalizerTest < Minitest::Test
  def test_normalizes_comma_and_newline_lists
    result = Commands::PublishInputNormalizer.call(
      ruby_versions_input: "3.3.1, 3.2.4\n3.1.9",
      image_versions_input: "1.1.0, ruby-1.2.0",
      repository: "rails/devcontainer"
    )

    assert_equal ["3.3.1", "3.2.4", "3.1.9"], result[:ruby_versions]
    assert_equal ["ruby-1.1.0", "ruby-1.2.0"], result[:image_versions]
    assert_equal '["3.3.1","3.2.4","3.1.9"]', result[:ruby_versions_json]
    assert_equal '["ruby-1.1.0","ruby-1.2.0"]', result[:image_versions_json]
  end

  def test_uses_latest_image_tag_when_image_versions_blank
    fetcher = ->(_repo) { "ruby-2.0.0" }

    result = Commands::PublishInputNormalizer.call(
      ruby_versions_input: "3.3.1",
      image_versions_input: "  ,  \n",
      repository: "rails/devcontainer",
      latest_tag_fetcher: fetcher
    )

    assert_equal ["ruby-2.0.0"], result[:image_versions]
    assert_equal '["ruby-2.0.0"]', result[:image_versions_json]
  end

  def test_raises_for_empty_ruby_versions
    error = assert_raises(Commands::PublishInputNormalizer::Error) do
      Commands::PublishInputNormalizer.call(
        ruby_versions_input: " , \n",
        image_versions_input: "1.1.0",
        repository: "rails/devcontainer"
      )
    end

    assert_match(/Ruby versions input is empty/, error.message)
  end

  def test_raises_when_latest_tag_is_missing
    fetcher = ->(_repo) { nil }

    error = assert_raises(Commands::PublishInputNormalizer::Error) do
      Commands::PublishInputNormalizer.call(
        ruby_versions_input: "3.3.1",
        image_versions_input: "",
        repository: "rails/devcontainer",
        latest_tag_fetcher: fetcher
      )
    end

    assert_match(/Image versions input is empty/, error.message)
  end
end
