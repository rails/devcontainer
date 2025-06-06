# Active Storage

Installs libvips, ffmpeg and poppler-utils which are required to use Active Storage for Rails apps.

## Example Usage

```json
"features": {
    "ghcr.io/rails/devcontainer/features/activestorage": {}
}
```

## Options

| Options Id | Description | Type | Default Value |
|-----|-----|-----|-----|
| variantProcessor | The image processing library to use with Active Storage | string | vips |

## Customizations

### VS Code Extensions

## OS Support

This Feature should work on recent versions of Debian/Ubuntu-based distributions with the `apt` package manager installed.

`bash` is required to execute the `install.sh` script.