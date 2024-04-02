# Postgres Client

Installs needed client-side dependencies for Rails apps using Postgres.

NOTE: This feature does not install the dependencies needed for the Postgres server. For that we recommend running a
service using the official [Postgres docker image](https://hub.docker.com/_/postgres).

## Example Usage

```json
"features": {
    "ghcr.io/rails/devcontainer/features/postgres-client": {}
}
```

## Options

## Customizations

## OS Support

This Feature should work on recent versions of Debian/Ubuntu-based distributions with the `apt` package manager installed.

`bash` is required to execute the `install.sh` script.