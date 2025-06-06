# Rails Dev Container Images & Features

This repository contains dev container images and features that can be used to create a convenient and consistent
development environment for working on Rails applications.

## What is a dev container?

A **dev container** is a running Docker container that provides a fully-featured development environment  which can be
used to run an application, to separate tools, libraries, or runtimes needed for working with a codebase, and to aid in
continuous integration and testing. **Dev container features** are self-contained units of installation and configuration
that can be installed on top of a container image to provide additional functionality in a container. **Dev container
images** are prebuilt docker images based on dev container features. For more information on the dev container
specification see https://containers.dev/.

## How to use the images and features in this repository

As of Rails 7.2, all newly generated Rails applications will come with a dev container that utilizes the images and
features in this repository to create a development environment for that app.

You can add a dev container to an existing application by creating `devcontainer.json` in the `.devcontainer/` directory
at the top level of the repository. A minimal dev container setup, for an application using SQLite and Active Storage
would look like this:

```json
{
  "image": "ghcr.io/rails/devcontainer/images/ruby:3.3.0",
  "features": {
    "ghcr.io/rails/devcontainer/features/activestorage": {}
  }
}
```

This dev container uses the Ruby image, which includes an installation of Ruby (in this case version 3.3.0) and a Ruby
version manager (mise by default, but configurable to use rbenv), as well as other common utilities such as Git. It also uses the Active Storage feature, which installs
dependencies needed for Active Storage.

The dev container can be initialized [by VSCode](https://code.visualstudio.com/docs/devcontainers/containers) or by using
the [dev container CLI](https://code.visualstudio.com/docs/devcontainers/devcontainer-cli).

Detailed information about the images and features provided by this repository can be found in their individual readme
files.

## Contributing

### Contributing to this repository

This repository is open for contributions. See [the contributions guide](CONTRIBUTING.md) for details.

### Creating your own features and images

You can create your own features, and images based on them.

The best place to start is the [feature starter repository](https://github.com/devcontainers/feature-starter) which is
maintained by the devcontainers org.

## License

The repository is released under the [MIT License](https://opensource.org/licenses/MIT).
