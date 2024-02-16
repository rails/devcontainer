# Ruby (via rbenv)

Installs Ruby, rbenv, and ruby-build as well as the dependencies needed to build Ruby.

## Example Usage

```json
"features": {
    "ghcr.io/rails/devcontainer/features/ruby:1": {
        "version": "3.3.0"
    }
}
```

## Options

| Options Id | Description | Type |
|-----|-----|-----|
| version | The version of ruby to be installed | string |

## Customizations

### VS Code Extensions

- `shopify.ruby-lsp`

## OS Support

This Feature should work on recent versions of Debian/Ubuntu-based distributions with the `apt` package manager installed.

`bash` is required to execute the `install.sh` script.