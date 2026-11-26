# Contributing

## Contributing to existing features

We welcome contributions to the existing features in this repo. If you have found a bug, or believe additional tooling
should be included in the feature installation, you are welcome to create a Github issue or to open a pull request
yourself. For pull requests please use the following process:

1. Fork this repository
2. Checkout a branch (on your fork) and commit your code
3. Push the branch to your fork on Github
4. Open a PR in this repository

## Contributing new features

The goal of this repository is to provide features for all common Rails dependencies. If you believe something is missing
that would be valuable to the Rails community, please open an issue in this repository.

For specialized use cases, you can also create your own features. The devcontainer org's [feature starter repository](https://github.com/devcontainers/feature-starter)
is the best place to start.

## Releasing features

Features are released using the [devcontainers/action](https://github.com/devcontainers/action) Github Action. When
the `version` in a feature's `devcontainer-feature.json` is updated on the `main` branch, this action will publish a
new version of that feature to `ghcr.io/rails/devcontainer/features/[feature name]`.

## Contributing to the ruby image

The Ruby image uses the Ruby feature and includes common utilities. Make changes to the Ruby installation in the feature.
A Ruby feature version increase starts the approval process for a full image release.

For other changes to the image not related to the ruby installation, issues or pull requests can be opened following
the same process as for features.

## Publish the image

The **Build and Publish Images** workflow uses [devcontainers/ci](https://github.com/devcontainers/ci).
For changes to the image source alone, push a tag such as `ruby-2.3.8` to start the workflow.
The tag identifies the image version, not the Ruby feature version or the Ruby version.
The workflow builds images for all Ruby versions in `.github/ruby-versions.json` at that tag.

You can also run the workflow manually with an existing tag in the `image_version` input.
Use this option if a tag exists but GitHub did not start the workflow.

The workflow uses `GITHUB_TOKEN` to find the latest stable Git version before it starts the builds.
Each build uses the same Git version. The workflow does not pass the token to the Docker build.

## Publishing new Ruby versions

When a new Ruby version is released, we need to add it to the build matrix and potentially update the default version.

### Step 1: Add the Ruby version to the build matrix

Use the automated script to update the configuration files:

```bash
bin/add-ruby-version 3.4.5
```

This script will:
- Add the version to the build matrix in `.github/ruby-versions.json`
- Update the default version in `features/src/ruby/devcontainer-feature.json` if the new version is newer
- Bump the feature version (patch increment) when the default Ruby version changes
- Update test files to use the new Ruby version
- Maintain proper semantic version ordering
- Prevent duplicate entries

After running the script, review the changes with `git diff`, commit them, and push.

### Step 2: Approve the image workflow

After feature publication succeeds on `main`, the release workflow checks whether it must dispatch an image workflow.
If it selects an image workflow, the `publish-images` job waits for one Rails Core approval in the `production` environment.
After approval, the job checks the latest image tag again.

- If the target feature version is newer than the feature version at the latest image tag, the job creates the next image patch tag.
  It dispatches **Build and Publish Images** for the full matrix.
- If a push increases the feature version and the latest image tag points to that push, the job reuses the tag.
- If only Ruby versions are missing, the job dispatches **Build and Publish New Ruby Versions** with those additions and the latest image tag.
- If a newer release already includes the changes, the job skips the dispatch.

To build specific versions manually, run **Build and Publish New Ruby Versions** with comma-separated inputs:

```text
ruby_versions: 3.4.5
image_versions: ruby-2.3.8
```
