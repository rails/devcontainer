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
that would be valueable to the Rails community, please open an issue in this repository.

For specialized use cases, you can also create your own features. The devcontainer org's [feature starter repository](https://github.com/devcontainers/feature-starter)
is the best place to start.

## Releasing features

Features are released using the [devcontainers/action](https://github.com/devcontainers/action) Github Action. When
the `version` in a feature's `devcontainer-feature.json` is updated on the `main` branch, this action will publish a
new version of that feature to `ghcr.io/rails/devcontainer/features/[feature name]`.

## Contributing to the ruby image

The ruby image consists of a dev container that utilizes the ruby feature in addition to some common utilities. Thus
changes to how ruby is installed (eg installation of additional dependencies) should be made to the ruby feature. When
a new version of the feature is published, and new version of the image will also be published.

For other changes to the image not related to the ruby installation, issues or pull requests can be opened following
the same process as for features.

## Publish the image

The image is published using the [devcontainers/ci](https://github.com/devcontainers/ci) Github Action. This workflow
is kicked off by the creation of a new tag on Github. Tags should be in the form `ruby-*.*.*`, where the * represent
the **image version** (not the ruby version). Images will be published for all [maintained Ruby versions](https://www.ruby-lang.org/en/downloads/).

## Publishing new Ruby versions

When a new Ruby version is released, we need to add it to the build matrix and potentially update the default version.

### Step 1: Add the Ruby version to the build matrix

Use the automated script to update the configuration files:

```bash
bin/add-ruby-version 3.4.5
```

This script will:
- Add the version to the build matrix in `.github/workflows/publish-new-image-version.yaml`
- Update the default version in `features/src/ruby/devcontainer-feature.json` if the new version is newer
- Maintain proper semantic version ordering
- Prevent duplicate entries

After running the script, review the changes with `git diff`, commit them, and push.

### Step 2: Publish the Ruby version

You have two options:

#### Option A: Publish specific Ruby versions (common)

For immediate publishing of specific Ruby versions without cutting a new image version, run the **Publish New Ruby Versions** workflow manually. The workflow takes a list of ruby versions and image tags as inputs, formatted as comma separated arrays:

```
ruby_versions: ["3.4.5"]
image_versions: ["ruby-1.1.0"]
```

#### Option B: Wait for next image release (automatic)

When a new image version is released (triggered by creating a `ruby-*.*.*` tag), the automatic workflow will build images for all Ruby versions in the matrix, including the newly added one.
