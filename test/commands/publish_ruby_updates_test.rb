# frozen_string_literal: true

require "minitest/autorun"
require "fileutils"
require "tmpdir"
require "webmock/minitest"
require_relative "../../lib/commands/publish_ruby_updates"

class PublishRubyUpdatesTest < Minitest::Test
  REPOSITORY = "rails/devcontainer"
  API = "https://api.github.com/repos/#{REPOSITORY}"
  BASE_TAG = "ruby-2.3.7"
  BASE_FEATURE = "2.2.7"
  BASE_VERSIONS = %w[4.0.10 3.4.13 3.3.14].freeze
  VERSIONS_PATH = ".github/ruby-versions.json"
  FEATURE_PATH = "features/src/ruby/devcontainer-feature.json"
  IMAGE_WORKFLOW = "publish-new-image-version.yaml"
  RUBY_WORKFLOW = "publish-new-ruby-versions.yaml"

  def setup
    WebMock.disable_net_connect!
    @dir = Dir.mktmpdir("publish-ruby-updates")
    git("init", "--quiet")
    git("config", "--local", "user.name", "Release Test")
    git("config", "--local", "user.email", "release@example.test")
    @before_sha = commit_snapshot
  end

  def teardown
    WebMock.reset!
    FileUtils.remove_entry(@dir)
  end

  def test_dispatches_only_the_new_ruby_version_against_the_latest_image_tag
    after = commit_snapshot(versions: BASE_VERSIONS + ["3.3.15"])
    stub_latest_image
    dispatch = stub_dispatch(RUBY_WORKFLOW, { ruby_versions: "3.3.15", image_versions: BASE_TAG })

    assert_equal decision("ruby", after, ["3.3.15"], BASE_TAG), publish(after)
    assert_requested dispatch, times: 1
    assert_not_requested :post, "#{API}/git/refs"
  end

  def test_feature_increase_creates_an_independent_image_tag_and_dispatches_the_full_workflow
    versions = BASE_VERSIONS + ["4.0.11"]
    after = commit_snapshot(versions: versions, feature: "2.2.8")
    stub_latest_image
    create = stub_create_tag("ruby-2.3.8", after)
    dispatch = stub_dispatch(IMAGE_WORKFLOW, { image_version: "ruby-2.3.8" })

    assert_equal decision("image", after, %w[4.0.11 4.0.10 3.4.13 3.3.14], "ruby-2.3.8", create_tag: true), publish(after)
    assert_requested create, times: 1
    assert_requested dispatch, times: 1
  end

  def test_feature_increase_without_an_addition_uses_the_full_matrix
    after = commit_snapshot(feature: "2.2.8")
    stub_latest_image
    create = stub_create_tag("ruby-2.3.8", after)
    dispatch = stub_dispatch(IMAGE_WORKFLOW, { image_version: "ruby-2.3.8" })

    assert_equal decision("image", after, BASE_VERSIONS, "ruby-2.3.8", create_tag: true), publish(after)
    assert_requested create, times: 1
    assert_requested dispatch, times: 1
  end

  def test_addition_after_an_unreleased_feature_increase_uses_the_full_matrix
    before = commit_snapshot(feature: "2.2.8")
    versions = BASE_VERSIONS + ["3.3.15"]
    after = commit_snapshot(versions: versions, feature: "2.2.8")
    stub_latest_image

    assert_equal decision("image", after, %w[4.0.10 3.4.13 3.3.15 3.3.14], "ruby-2.3.8", create_tag: true),
      publish(after, before_ref: before, dry_run: true)
    assert_no_mutations
  end

  def test_reuses_a_tag_that_already_points_to_the_feature_update
    versions = ["4.0.11"] + BASE_VERSIONS
    after = commit_snapshot(versions: versions, feature: "2.2.8")
    stub_latest_image(tag: "ruby-2.3.8", versions: versions, feature: "2.2.8", sha: after)
    dispatch = stub_dispatch(IMAGE_WORKFLOW, { image_version: "ruby-2.3.8" })

    assert_equal decision("image", after, versions, "ruby-2.3.8"), publish(after)
    assert_requested dispatch, times: 1
    assert_not_requested :post, "#{API}/git/refs"
  end

  def test_reuses_the_tag_on_a_rerun_after_a_dispatch_error
    versions = ["4.0.11"] + BASE_VERSIONS
    after = commit_snapshot(versions: versions, feature: "2.2.8")
    stub_latest_image
    create = stub_create_tag("ruby-2.3.8", after)
    failed = stub_dispatch(IMAGE_WORKFLOW, { image_version: "ruby-2.3.8" }, status: 500)

    assert_raises(Commands::PublishRubyUpdates::Error) { publish(after) }
    assert_requested create, times: 1
    assert_requested failed, times: 1

    WebMock.reset!
    stub_latest_image(tag: "ruby-2.3.8", versions: versions, feature: "2.2.8", sha: after)
    dispatch = stub_dispatch(IMAGE_WORKFLOW, { image_version: "ruby-2.3.8" })

    assert_equal decision("image", after, versions, "ruby-2.3.8"), publish(after)
    assert_requested dispatch, times: 1
    assert_not_requested :post, "#{API}/git/refs"
  end

  def test_a_false_dispatch_result_is_an_error
    after = commit_snapshot(versions: BASE_VERSIONS + ["3.3.15"])
    stub_latest_image
    dispatch = stub_dispatch(RUBY_WORKFLOW, { ruby_versions: "3.3.15", image_versions: BASE_TAG }, status: 404)

    assert_raises(Commands::PublishRubyUpdates::Error) { publish(after) }
    assert_requested dispatch, times: 1
  end

  def test_skips_updates_that_a_newer_image_already_includes
    versions = ["4.0.11"] + BASE_VERSIONS
    after = commit_snapshot(versions: versions, feature: "2.2.8")
    stub_latest_image(tag: "ruby-2.3.9", versions: ["4.0.12"] + versions, feature: "2.2.9", sha: "a" * 40)

    assert_equal decision("none", after), publish(after)
    assert_no_mutations
  end

  def test_selects_only_added_versions_that_are_missing_from_the_latest_image
    after = commit_snapshot(versions: BASE_VERSIONS + %w[3.3.15 3.4.14])
    stub_latest_image(versions: BASE_VERSIONS + ["3.4.14"])
    dispatch = stub_dispatch(RUBY_WORKFLOW, { ruby_versions: "3.3.15", image_versions: BASE_TAG })

    assert_equal decision("ruby", after, ["3.3.15"], BASE_TAG), publish(after)
    assert_requested dispatch, times: 1
  end

  def test_skips_removals_order_changes_and_image_source_changes_without_remote_reads
    write("images/ruby/Dockerfile", "FROM scratch\n")
    after = commit_snapshot(versions: %w[3.3.14 4.0.10])

    assert_equal decision("none", after), publish(after, github_token: nil)
    assert_not_requested :any, %r{\Ahttps://api\.github\.com/}
  end

  def test_reads_the_full_range_and_not_the_working_tree
    commit_snapshot(versions: BASE_VERSIONS + ["3.3.15"])
    write("images/ruby/Dockerfile", "FROM scratch\n")
    after = commit
    write(VERSIONS_PATH, "invalid JSON in the working tree")
    stub_latest_image
    dispatch = stub_dispatch(RUBY_WORKFLOW, { ruby_versions: "3.3.15", image_versions: BASE_TAG })

    assert_equal decision("ruby", after, ["3.3.15"], BASE_TAG), publish(after)
    assert_requested dispatch, times: 1
  end

  def test_dry_run_selects_the_new_image_and_uses_numeric_order_without_mutations
    after = commit_snapshot(versions: ["4.0.9", "4.0.10", "3.4.13", "4.0.11", "3.3.14"], feature: "2.2.8")
    stub_latest_image

    assert_equal decision("image", after, %w[4.0.11 4.0.10 4.0.9 3.4.13 3.3.14], "ruby-2.3.8", create_tag: true),
      publish(after, dry_run: true, github_token: nil)
    assert_no_mutations
  end

  def test_dry_run_selects_ruby_additions_in_numeric_order_without_mutations
    after = commit_snapshot(versions: BASE_VERSIONS + %w[3.3.9 3.3.15])
    stub_latest_image

    assert_equal decision("ruby", after, %w[3.3.15 3.3.9], BASE_TAG), publish(after, dry_run: true)
    assert_no_mutations
  end

  def test_rejects_an_absent_zero_unresolvable_or_non_ancestor_ref
    after = commit_snapshot(versions: BASE_VERSIONS + ["3.3.15"])

    [nil, "0" * 40, "missing-ref"].each do |ref|
      assert_raises(Commands::PublishRubyUpdates::Error) { publish(after, before_ref: ref) }
      assert_raises(Commands::PublishRubyUpdates::Error) { publish(ref) }
    end
    assert_raises(Commands::PublishRubyUpdates::Error) { publish(@before_sha, before_ref: after) }
    assert_not_requested :any, %r{\Ahttps://api\.github\.com/}
  end

  def test_fails_if_git_cannot_read_a_snapshot_file
    File.delete(File.join(@dir, FEATURE_PATH))
    after = commit

    assert_raises(Commands::PublishRubyUpdates::Error) { publish(after) }
    assert_not_requested :any, %r{\Ahttps://api\.github\.com/}
  end

  def test_rejects_invalid_local_json_and_version_data
    ["[", JSON.generate({ versions: BASE_VERSIONS }), JSON.generate(["4.0.11-rc1"]), JSON.generate([3])].each do |content|
      write(VERSIONS_PATH, content)
      assert_raises(Commands::PublishRubyUpdates::Error) { publish(commit) }
    end
    after = commit_snapshot(feature: "2.2")
    assert_raises(Commands::PublishRubyUpdates::Error) { publish(after) }
    assert_not_requested :any, %r{\Ahttps://api\.github\.com/}
  end

  def test_rejects_feature_decreases_and_empty_target_matrices_for_an_image_release
    after = commit_snapshot(feature: "2.2.6")
    assert_raises(Commands::PublishRubyUpdates::Error) { publish(after) }
    after = commit_snapshot(versions: [], feature: "2.2.8")
    assert_raises(Commands::PublishRubyUpdates::Error) { publish(after) }
    assert_not_requested :any, %r{\Ahttps://api\.github\.com/}
  end

  def test_rejects_a_missing_or_invalid_latest_tag
    after = commit_snapshot(versions: BASE_VERSIONS + ["3.3.15"])

    [nil, "ruby-2.3.7-rc1", "ruby-2.3.7,ruby-2.3.8"].each do |tag|
      assert_raises(Commands::PublishRubyUpdates::Error) { publish(after, latest_tag_fetcher: ->(_) { tag }) }
    end
    assert_not_requested :any, %r{\Ahttps://api\.github\.com/}
  end

  def test_fails_if_github_cannot_read_the_tag_contents
    after = commit_snapshot(versions: BASE_VERSIONS + ["3.3.15"])
    @latest_tag = BASE_TAG
    request = stub_request(:get, contents_url(BASE_TAG, VERSIONS_PATH)).to_return(status: 404)

    assert_raises(Commands::PublishRubyUpdates::Error) { publish(after) }
    assert_requested request, times: 1
    assert_no_mutations
  end

  def test_rejects_missing_or_invalid_remote_file_data
    after = commit_snapshot(versions: BASE_VERSIONS + ["3.3.15"])
    @latest_tag = BASE_TAG
    stub_contents(BASE_TAG, VERSIONS_PATH, JSON.generate(BASE_VERSIONS))

    [{}, { "content" => "malformed!" }, { "content" => Base64.strict_encode64("[") }].each do |body|
      stub_request(:get, contents_url(BASE_TAG, FEATURE_PATH)).to_return(json_response(body))
      assert_raises(Commands::PublishRubyUpdates::Error) { publish(after) }
    end
    assert_no_mutations
  end

  def test_rejects_invalid_remote_commit_data
    after = commit_snapshot(versions: BASE_VERSIONS + ["3.3.15"])
    stub_latest_image(sha: "not-a-sha")

    assert_raises(Commands::PublishRubyUpdates::Error) { publish(after) }
    assert_no_mutations
  end

  def test_requires_a_token_before_any_mutation
    after = commit_snapshot(feature: "2.2.8")
    stub_latest_image

    assert_raises(Commands::PublishRubyUpdates::Error) { publish(after, github_token: nil) }
    assert_no_mutations
  end

  def test_fails_on_a_tag_conflict_without_moving_the_tag_or_dispatching
    after = commit_snapshot(feature: "2.2.8")
    stub_latest_image
    conflict = stub_create_tag("ruby-2.3.8", after, status: 409)

    assert_raises(Commands::PublishRubyUpdates::Error) { publish(after) }
    assert_requested conflict, times: 1
    assert_not_requested :any, %r{#{API}/actions/workflows/}
    assert_not_requested :patch, %r{#{API}/git/refs}
    assert_not_requested :delete, %r{#{API}/git/refs}
  end

  private

  def git(*args)
    stdout, stderr, status = Open3.capture3("git", *args, chdir: @dir)
    raise "git #{args.first} failed: #{stderr}" unless status.success?

    stdout.strip
  end

  def write(path, content)
    file = File.join(@dir, path)
    FileUtils.mkdir_p(File.dirname(file))
    File.write(file, content)
  end

  def commit
    git("add", "--all")
    git("commit", "--quiet", "--no-gpg-sign", "--allow-empty", "-m", "Fixture snapshot")
    git("rev-parse", "HEAD")
  end

  def commit_snapshot(versions: BASE_VERSIONS, feature: BASE_FEATURE)
    write(VERSIONS_PATH, JSON.generate(versions))
    write(FEATURE_PATH, JSON.generate({ version: feature }))
    commit
  end

  def publish(after, **overrides)
    options = {
      working_dir: @dir, before_ref: @before_sha, after_ref: after,
      repository: REPOSITORY, github_token: "test-token",
      latest_tag_fetcher: ->(_) { @latest_tag || flunk("Unexpected latest tag lookup") }
    }
    Commands::PublishRubyUpdates.call(**options.merge(overrides))
  end

  def decision(mode, source_sha, ruby_versions = [], image_tag = nil, create_tag: false)
    { mode:, ruby_versions:, image_tag:, source_sha:, create_tag: }
  end

  def stub_latest_image(tag: BASE_TAG, versions: BASE_VERSIONS, feature: BASE_FEATURE, sha: @before_sha)
    @latest_tag = tag
    stub_contents(tag, VERSIONS_PATH, JSON.generate(versions))
    stub_contents(tag, FEATURE_PATH, JSON.generate({ version: feature }))
    stub_request(:get, "#{API}/commits/#{tag}").to_return(json_response({ sha: sha }))
  end

  def stub_contents(tag, path, content)
    stub_request(:get, contents_url(tag, path)).to_return(json_response({ content: Base64.encode64(content) }))
  end

  def contents_url(tag, path)
    "#{API}/contents/#{path}?ref=#{tag}"
  end

  def stub_create_tag(tag, sha, status: 201)
    stub_request(:post, "#{API}/git/refs")
      .with(body: { ref: "refs/tags/#{tag}", sha: sha }, headers: { "Authorization" => "token test-token" })
      .to_return(json_response({ ref: "refs/tags/#{tag}" }, status: status))
  end

  def stub_dispatch(workflow, inputs, status: 204)
    stub_request(:post, "#{API}/actions/workflows/#{workflow}/dispatches")
      .with(body: { ref: "main", inputs: inputs }, headers: { "Authorization" => "token test-token" })
      .to_return(status: status)
  end

  def json_response(body, status: 200)
    { status: status, body: JSON.generate(body), headers: { "Content-Type" => "application/json" } }
  end

  def assert_no_mutations
    %i[post put patch delete].each do |method|
      assert_not_requested method, %r{\Ahttps://api\.github\.com/}
    end
  end
end
