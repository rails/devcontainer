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

### Opting in to precompiled Rubies with mise

```json
"features": {
    "ghcr.io/rails/devcontainer/features/ruby:1": {
        "version": "3.3.0",
        "versionManager": "mise",
        "usePrecompiledRubies": true
    }
}
```

When using `mise`, this feature keeps `ruby.compile=true` by default so Ruby is compiled from source. Set `usePrecompiledRubies` to `true` to make mise prefer precompiled Rubies when they are available.

## Options

| Options Id | Description | Type | Default Value |
|-----|-----|-----|-----|
| version | The version of ruby to be installed | string | 4.0.3 |
| versionManager | The version manager to use for Ruby (mise or rbenv) | string | mise |
| usePrecompiledRubies | Use precompiled Rubies with mise when available | boolean | false |

## Customizations

### VS Code Extensions

- [`shopify.ruby-lsp`](https://marketplace.visualstudio.com/items?itemName=Shopify.ruby-lsp)
- [`marcoroth.herb-lsp`](https://marketplace.visualstudio.com/items?itemName=marcoroth.herb-lsp)

## OS Support

This Feature should work on recent versions of Debian/Ubuntu-based distributions with the `apt` package manager installed.

`bash` is required to execute the `install.sh` script.
