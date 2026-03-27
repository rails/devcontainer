## OS Support

This Feature should work on recent versions of Debian/Ubuntu-based distributions with the `apt` package manager installed.

## Changing the Ruby Version

```json
"features": {
    "ghcr.io/rails/devcontainer/features/ruby:1": {
        "version": "3.3.0"
    }
}
```

## Changing the Version Manager

```json
"features": {
    "ghcr.io/rails/devcontainer/features/ruby:1": {
        "versionManager": "rbenv"
    }
}
```

## Opting In to Precompiled Rubies with mise

```json
"features": {
    "ghcr.io/rails/devcontainer/features/ruby:1": {
        "versionManager": "mise",
        "usePrecompiledRubies": true
    }
}
```

When using `mise`, this feature keeps `ruby.compile=true` by default so Ruby is compiled from source. Set `usePrecompiledRubies` to `true` to make mise prefer precompiled Rubies when they are available.
