# monk-cli

`monk` is the Rust CLI for the Monk API.

## Release and install

The release process is tag-based and publishes GitHub Release assets for:

- `x86_64-unknown-linux-gnu`
- `x86_64-apple-darwin`
- `aarch64-apple-darwin`

Homebrew is intentionally excluded for now.

### Curl install

Install from the latest GitHub release:

```bash
curl -fsSL https://raw.githubusercontent.com/ianzepp/monk-cli/main/scripts/install.sh | bash
```

To pin a version:

```bash
MONK_CLI_VERSION=v0.1.0 \
  curl -fsSL https://raw.githubusercontent.com/ianzepp/monk-cli/main/scripts/install.sh | bash
```

Optional install directory:

```bash
MONK_CLI_INSTALL_DIR="$HOME/bin" \
  curl -fsSL https://raw.githubusercontent.com/ianzepp/monk-cli/main/scripts/install.sh | bash
```

## Current state

The CLI now has a shared API helper layer plus command-family dispatch wired up to Monk routes. The `data` family is aligned to Monk's model, record, relationship, and nested-child route shapes, with query flags threaded through the request helpers.
