# Ruby

Installs Ruby and a version manager (mise or rbenv) along with the dependencies needed to build Ruby.

## Example Usage

### Using mise (default)

```json
"features": {
    "ghcr.io/rails/devcontainer/features/ruby:1": {
        "version": "3.3.0"
    }
}
```

### Using rbenv

```json
"features": {
    "ghcr.io/rails/devcontainer/features/ruby:1": {
        "version": "3.3.0",
        "versionManager": "rbenv"
    }
}
```

### Using mise explicitly

```json
"features": {
    "ghcr.io/rails/devcontainer/features/ruby:1": {
        "version": "3.3.0",
        "versionManager": "mise"
    }
}
```

## Options

| Options Id | Description | Type | Default Value |
|-----|-----|-----|-----|
| version | The version of ruby to be installed | string | 3.4.1 |
| versionManager | The version manager to use for Ruby (mise or rbenv) | string | mise |

## Customizations

### VS Code Extensions

- `shopify.ruby-lsp`

## OS Support

This Feature should work on recent versions of Debian/Ubuntu-based distributions with the `apt` package manager installed.

`bash` is required to execute the `install.sh` script.
