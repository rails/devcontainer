# MySQL Client

Installs needed client-side dependencies for Rails apps using MySQL.

NOTE: This feature does not install the dependencies needed for the MySQL Server. For that we recommend running a
service using the official [MySQL docker image](https://hub.docker.com/_/mysql).

## Example Usage

```json
"features": {
    "ghcr.io/rails/devcontainer/features/mysql-client": {}
}
```

## Options

## Customizations

## OS Support

This Feature should work on recent versions of Debian/Ubuntu-based distributions with the `apt` package manager installed.

`bash` is required to execute the `install.sh` script.