# frozen_string_literal: true

require "base64"
require "json"
require "octokit"
require "open3"
require "rubygems"
require_relative "publish_input_normalizer"

module Commands
  class PublishRubyUpdates
    class Error < StandardError; end

    RUBY_VERSIONS_PATH = ".github/ruby-versions.json"
    FEATURE_PATH = "features/src/ruby/devcontainer-feature.json"
    VERSION = /\A[0-9]+\.[0-9]+\.[0-9]+\z/
    IMAGE_TAG = /\Aruby-([0-9]+)\.([0-9]+)\.([0-9]+)\z/

    def self.call(working_dir:, before_ref:, after_ref:, repository:, github_token: nil, latest_tag_fetcher: nil, dry_run: false)
      new(working_dir:, before_ref:, after_ref:, repository:, github_token:, latest_tag_fetcher:, dry_run:).call
    end

    def initialize(working_dir:, before_ref:, after_ref:, repository:, github_token:, latest_tag_fetcher:, dry_run:)
      @working_dir = working_dir
      @before_ref = before_ref
      @after_ref = after_ref
      @repository = repository
      @github_token = github_token
      @latest_tag_fetcher = latest_tag_fetcher
      @dry_run = dry_run
    end

    def call
      before_sha = resolve_commit(@before_ref, "before_ref")
      source_sha = resolve_commit(@after_ref, "after_ref")
      git("merge-base", "--is-ancestor", before_sha, source_sha, error: "Cannot verify that before_ref is an ancestor of after_ref")

      before_versions, before_feature = read_snapshot(before_sha) { |path| git("show", "#{before_sha}:#{path}") }
      after_versions, after_feature = read_snapshot(source_sha) { |path| git("show", "#{source_sha}:#{path}") }
      raise Error, "Ruby feature version decreased from #{before_feature} to #{after_feature}" if after_feature < before_feature

      added_versions = after_versions - before_versions
      feature_increased = after_feature > before_feature
      result = decision("none", source_sha)
      return result if added_versions.empty? && !feature_increased

      raise Error, "Target Ruby matrix is empty" if after_versions.empty?

      latest_tag = latest_image_tag(after_versions)
      client = Octokit::Client.new(access_token: @github_token)
      tagged_versions, tagged_feature = read_snapshot(latest_tag) { |path| remote_file(client, latest_tag, path) }
      tagged_sha = remote_commit(client, latest_tag)
      missing_versions = added_versions - tagged_versions

      if feature_increased && tagged_sha == source_sha
        result = decision("image", source_sha, after_versions, latest_tag)
      elsif after_feature > tagged_feature
        result = decision("image", source_sha, after_versions, next_image_tag(latest_tag), create_tag: true)
      elsif !missing_versions.empty?
        result = decision("ruby", source_sha, missing_versions, latest_tag)
      end

      dispatch(client, result) unless @dry_run || result[:mode] == "none"
      result
    rescue PublishInputNormalizer::Error => e
      raise Error, e.message
    rescue SystemCallError => e
      raise Error, "Git failed: #{e.message}"
    end

    private

    def resolve_commit(ref, name)
      raise Error, "#{name} must be a nonzero Git ref" if ref.to_s.strip.empty? || /\A0+\z/.match?(ref)

      git("rev-parse", "--verify", "--end-of-options", "#{ref}^{commit}", error: "Cannot resolve #{name}").strip
    end

    def git(*args, error: "Git #{args.first} failed")
      stdout, stderr, status = Open3.capture3("git", *args, chdir: @working_dir)
      raise Error, [error, stderr.strip].reject(&:empty?).join(": ") unless status.success?

      stdout
    end

    def read_snapshot(ref)
      versions = parse_json(yield(RUBY_VERSIONS_PATH), RUBY_VERSIONS_PATH, ref)
      unless versions.is_a?(Array) && versions.all? { |version| version.is_a?(String) && VERSION.match?(version) }
        raise Error, "Expected an array of numeric x.y.z Ruby versions in #{RUBY_VERSIONS_PATH} at #{ref}"
      end

      feature = parse_json(yield(FEATURE_PATH), FEATURE_PATH, ref)
      version = feature["version"] if feature.is_a?(Hash)
      unless version.is_a?(String) && VERSION.match?(version)
        raise Error, "Expected a numeric x.y.z feature version in #{FEATURE_PATH} at #{ref}"
      end

      [versions, Gem::Version.new(version)]
    end

    def parse_json(content, path, ref)
      JSON.parse(content)
    rescue JSON::ParserError
      raise Error, "Invalid JSON in #{path} at #{ref}"
    end

    def latest_image_tag(after_versions)
      image_versions = PublishInputNormalizer.call(
        ruby_versions_input: after_versions.join(","),
        image_versions_input: "",
        repository: @repository,
        latest_tag_fetcher: @latest_tag_fetcher
      ).fetch(:image_versions)
      unless image_versions.size == 1 && IMAGE_TAG.match?(image_versions.first)
        raise Error, "Expected one latest image tag in ruby-X.Y.Z format"
      end

      image_versions.first
    end

    def remote_file(client, tag, path)
      file = github_request("read #{path} at #{tag}") { client.contents(@repository, path: path, ref: tag) }
      content = file.content if file.respond_to?(:content)
      unless content.is_a?(String) && !content.strip.empty?
        raise Error, "Missing content for #{path} at #{tag}"
      end

      Base64.strict_decode64(content.delete("\r\n"))
    rescue ArgumentError
      raise Error, "Invalid Base64 content for #{path} at #{tag}"
    end

    def remote_commit(client, tag)
      commit = github_request("resolve the commit for #{tag}") { client.commit(@repository, tag) }
      sha = commit.sha if commit.respond_to?(:sha)
      unless sha.is_a?(String) && /\A[0-9a-f]{40}\z/.match?(sha) && !/\A0+\z/.match?(sha)
        raise Error, "Invalid commit SHA for #{tag}"
      end

      sha
    end

    def next_image_tag(tag)
      major, minor, patch = IMAGE_TAG.match(tag).captures
      "ruby-#{major}.#{minor}.#{patch.to_i + 1}"
    end

    def decision(mode, source_sha, ruby_versions = [], image_tag = nil, create_tag: false)
      { mode:, ruby_versions: ruby_versions.uniq.sort_by { |version| Gem::Version.new(version) }.reverse,
        image_tag:, source_sha:, create_tag: }
    end

    def dispatch(client, result)
      raise Error, "GITHUB_TOKEN is required to dispatch an image workflow" if @github_token.to_s.strip.empty?

      tag = result.fetch(:image_tag)
      if result.fetch(:create_tag)
        github_request("create image tag #{tag}") { client.create_ref(@repository, "tags/#{tag}", result.fetch(:source_sha)) }
      end

      if result.fetch(:mode) == "image"
        workflow = "publish-new-image-version.yaml"
        inputs = { image_version: tag }
      else
        workflow = "publish-new-ruby-versions.yaml"
        inputs = { ruby_versions: result.fetch(:ruby_versions).join(","), image_versions: tag }
      end
      dispatched = github_request("dispatch #{workflow}") { client.workflow_dispatch(@repository, workflow, "main", inputs: inputs) }
      raise Error, "GitHub did not accept the dispatch for #{workflow}" unless dispatched
    end

    def github_request(operation)
      yield
    rescue Octokit::Error, Faraday::Error, JSON::ParserError => e
      raise Error, "Unable to #{operation}: #{e.class}"
    end
  end
end
