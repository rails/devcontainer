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
the **image version** (not the ruby version). Images will be published for all `3.*.*` ruby versions.

## Publishing new Ruby versions

When a new Ruby version is released, we can build and publish the existing image for the new ruby version, without
needing to cut a new version of the image itself. To do this, we can run the Publish New Ruby Versions workflow
manually. The workflow takes a list of a ruby versions and a list of image tags as inputs. They should be formatted
as comma separated arrays. For example:

```
ruby_versions: ["3.3.1","3.2.4","3.1.5","3.0.7"]
image_versions: ["ruby-0.3.0"]
```