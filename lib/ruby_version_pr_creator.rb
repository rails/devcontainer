# frozen_string_literal: true

require "octokit"
require "open3"
require "time"
require_relative "console"

# Ruby Version PR Creator
#
# This class handles creating pull requests for new Ruby versions.
# It uses Octokit for GitHub API operations and git for local operations.
class RubyVersionPRCreator
  include Console

  # Custom error class for PR creation errors
  class Error < StandardError; end

  class << self
    # Create a PR for new Ruby versions
    #
    # @param new_versions [Array<String>] The new versions that were added
    # @param files_modified [Array<String>] List of files that were modified
    # @param working_dir [String] The directory to operate in
    # @param github_token [String, nil] GitHub token for API requests
    # @param output [IO] Output stream for messages (default: $stdout)
    # @return [Hash] Result with :success, :pr_number, and :pr_url keys
    def call(new_versions, files_modified:, working_dir:, github_token: nil, output: $stdout)
      new(
        new_versions,
        files_modified: files_modified,
        working_dir: working_dir,
        github_token: github_token,
        output: output
      ).call
    end
  end

  attr_reader :new_versions, :files_modified, :working_dir, :github_token, :output

  def initialize(new_versions, files_modified:, working_dir:, github_token: nil, output: $stdout)
    @new_versions = new_versions
    @files_modified = files_modified
    @working_dir = working_dir
    @github_token = github_token || ENV["GITHUB_TOKEN"]
    @output = output
  end

  def call
    validate_prerequisites!

    close_existing_automation_prs

    branch_name = create_branch
    commit_changes
    push_branch(branch_name)
    pr_result = create_pull_request(branch_name)

    log("")
    log("Successfully created PR ##{pr_result[:number]}", :green, emoji: :check)
    log("URL: #{pr_result[:url]}", emoji: :info)

    { success: true, pr_number: pr_result[:number], pr_url: pr_result[:url] }
  rescue Error => e
    log("Error: #{e.message}", :red, emoji: :error)
    { success: false, error: e.message }
  end

  private

  def run_git(*args, allow_failure: false)
    cmd = ["git"] + args
    stdout, stderr, status = Open3.capture3(*cmd, chdir: working_dir)

    unless status.success? || allow_failure
      raise Error, "Git command failed: git #{args.join(' ')}\n#{stderr}"
    end

    { stdout: stdout.strip, stderr: stderr.strip, success: status.success? }
  end

  # Create an Octokit client
  #
  # @return [Octokit::Client] Configured GitHub client
  def github_client
    @github_client ||= Octokit::Client.new(access_token: github_token)
  end

  # Get the repository name from git remote
  #
  # @return [String] Repository in "owner/repo" format
  def repository
    @repository ||= begin
      result = run_git("remote", "get-url", "origin")
      url = result[:stdout]

      # Handle both HTTPS and SSH URLs
      # https://github.com/owner/repo.git
      # git@github.com:owner/repo.git
      match = url.match(%r{github\.com[/:](.+?/.+?)(?:\.git)?$})
      raise Error, "Could not parse repository from remote URL: #{url}" unless match

      match[1]
    end
  end

  def validate_prerequisites!
    # Check if we have a GitHub token
    unless github_token
      raise Error, "GitHub token required. Set GITHUB_TOKEN environment variable."
    end

    # Check if git is available
    result = run_git("--version", allow_failure: true)
    unless result[:success]
      raise Error, "Git is not installed or not in PATH."
    end

    # Verify we can authenticate with GitHub
    begin
      github_client.user
    rescue Octokit::Unauthorized
      raise Error, "GitHub API authentication failed. Check your token."
    rescue Octokit::Error => e
      raise Error, "GitHub API error: #{e.message}"
    end

    # Check if git user is configured
    result = run_git("config", "user.name", allow_failure: true)
    if result[:stdout].empty?
      log("Configuring git user for commits...", :blue, emoji: :info)
      run_git("config", "--local", "user.name", "github-actions[bot]")
      run_git("config", "--local", "user.email", "github-actions[bot]@users.noreply.github.com")
    end
  end

  def close_existing_automation_prs
    log("Checking for existing automation PRs...", :blue, emoji: :info)

    begin
      # Search for open PRs with automation labels
      prs = github_client.pull_requests(repository, state: "open")
      automation_prs = prs.select do |pr|
        labels = pr.labels.map(&:name)
        labels.include?("automation") && labels.include?("ruby-versions")
      end

      automation_prs.each do |pr|
        log("Closing existing PR ##{pr.number}...", :yellow, emoji: :close)
        github_client.add_comment(
          repository,
          pr.number,
          "Closing this PR as new Ruby versions are available. A new PR will be created."
        )
        github_client.close_pull_request(repository, pr.number)
      end
    rescue Octokit::Error => e
      # Non-fatal, just log and continue
      log("Could not check for existing PRs: #{e.message}", :yellow, emoji: :info)
    end
  end

  def create_branch
    timestamp = Time.now.strftime("%Y%m%d-%H%M%S")
    branch_name = "automated/ruby-versions-#{timestamp}"

    log("Creating branch: #{branch_name}", :blue, emoji: :branch)

    # Make sure we're on the latest main
    run_git("fetch", "origin", "main", allow_failure: true)

    # Create and checkout the new branch
    run_git("checkout", "-b", branch_name)

    branch_name
  end

  def commit_changes
    version_list = new_versions.join(", ")
    commit_message = "Add Ruby versions: #{version_list} [automated-ruby-update]"

    log("Committing changes...", :blue, emoji: :commit)

    # Stage all changes
    run_git("add", ".")

    # Commit
    run_git("commit", "-m", commit_message)
  end

  def push_branch(branch_name)
    log("Pushing to origin...", :blue, emoji: :push)
    run_git("push", "origin", branch_name)
  end

  def create_pull_request(branch_name)
    log("Creating pull request...", :blue, emoji: :pr)

    pr_body = generate_pr_body

    begin
      pr = github_client.create_pull_request(
        repository,
        "main",
        branch_name,
        pr_title,
        pr_body
      )

      # Add labels
      github_client.add_labels_to_an_issue(repository, pr.number, ["automation", "ruby-versions"])

      { number: pr.number, url: pr.html_url }
    rescue Octokit::UnprocessableEntity => e
      raise Error, "Could not create pull request: #{e.message}"
    rescue Octokit::Error => e
      raise Error, "GitHub API error creating PR: #{e.message}"
    end
  end

  def pr_title
    if new_versions.size == 1
      "Add Ruby version: #{new_versions.first}"
    else
      "Add Ruby versions: #{new_versions.join(', ')}"
    end
  end

  def generate_pr_body
    versions_list = new_versions.map { |v| "- #{v}" }.join("\n")
    files_list = files_modified.map { |f| "- `#{f}`" }.join("\n")

    body = <<~MARKDOWN
      ## 🤖 Automated Ruby Version Update

      This PR adds #{new_versions.size} new Ruby version(s) detected from [rbenv/ruby-build](https://github.com/rbenv/ruby-build):

      #{versions_list}

      ### Changes Made

      #{files_list}

      ### Details

      - Updated Ruby version matrix in `.github/ruby-versions.json`
      - Updated default Ruby version in `features/src/ruby/devcontainer-feature.json` (if applicable)
      - Updated documentation in `features/src/ruby/README.md` (if applicable)
      - Updated test files to use new default version (if applicable)
      - Bumped feature version (if default Ruby version changed)

      ### Next Steps

      After this PR is merged:
      1. Feature will be published automatically if version was bumped
      2. Images will be built and published (requires approval)
      3. GitHub releases will be created

      ---

      *This PR was created automatically by the Ruby version checker script.*
    MARKDOWN

    # Add run URL if available in GitHub Actions
    if ENV["GITHUB_SERVER_URL"] && ENV["GITHUB_REPOSITORY"] && ENV["GITHUB_RUN_ID"]
      run_url = "#{ENV['GITHUB_SERVER_URL']}/#{ENV['GITHUB_REPOSITORY']}/actions/runs/#{ENV['GITHUB_RUN_ID']}"
      body += "\n*Run: #{run_url}*"
    end

    body
  end
end
