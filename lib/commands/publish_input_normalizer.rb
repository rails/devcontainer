# frozen_string_literal: true

require "json"
require "open3"
require "rubygems"

module Commands
  class PublishInputNormalizer
    class Error < StandardError; end

    class << self
      def call(ruby_versions_input:, image_versions_input:, repository:, latest_tag_fetcher: nil)
        new(
          ruby_versions_input: ruby_versions_input,
          image_versions_input: image_versions_input,
          repository: repository,
          latest_tag_fetcher: latest_tag_fetcher
        ).call
      end
    end

    attr_reader :ruby_versions_input, :image_versions_input, :repository, :latest_tag_fetcher

    def initialize(ruby_versions_input:, image_versions_input:, repository:, latest_tag_fetcher: nil)
      @ruby_versions_input = ruby_versions_input.to_s
      @image_versions_input = image_versions_input.to_s
      @repository = repository.to_s
      @latest_tag_fetcher = latest_tag_fetcher || method(:fetch_latest_image_tag)
    end

    def call
      ruby_versions = normalize_list(ruby_versions_input)
      raise Error, "Ruby versions input is empty" if ruby_versions.empty?

      images_source = image_versions_input
      if blank_list?(images_source)
        images_source = latest_tag_fetcher.call(repository)
      end

      image_versions = normalize_image_versions(normalize_list(images_source))
      raise Error, "Image versions input is empty" if image_versions.empty?

      {
        ruby_versions: ruby_versions,
        image_versions: image_versions,
        ruby_versions_json: JSON.generate(ruby_versions),
        image_versions_json: JSON.generate(image_versions)
      }
    end

    private

    def blank_list?(value)
      value.to_s.gsub(/[\s,]/, "").empty?
    end

    def normalize_list(value)
      value
        .to_s
        .split(/[\n,]/)
        .map(&:strip)
        .reject(&:empty?)
    end

    def normalize_image_versions(versions)
      versions.map { |version| version.start_with?("ruby-") ? version : "ruby-#{version}" }
    end

    def fetch_latest_image_tag(repo)
      raise Error, "Repository is required to discover latest image tag" if repo.empty?

      stdout, status = Open3.capture2(
        "git",
        "ls-remote",
        "--tags",
        "--refs",
        "https://github.com/#{repo}.git",
        "refs/tags/ruby-*"
      )

      unless status.success?
        raise Error, "Unable to resolve latest ruby-* image tag"
      end

      tags = stdout.lines.map do |line|
        ref = line.split[1]
        ref&.sub("refs/tags/", "")
      end.compact

      latest = tags.max_by { |tag| version_for(tag) }
      raise Error, "Unable to resolve latest ruby-* image tag" unless latest

      latest
    end

    def version_for(tag)
      raw = tag.sub(/^ruby-/, "")
      Gem::Version.new(raw)
    rescue ArgumentError
      Gem::Version.new("0")
    end
  end
end
