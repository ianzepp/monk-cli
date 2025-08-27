# Monk CLI

Command-line interface for the Monk API - a bashly-based CLI tool.

## Quick Start

1. **Install globally:**
   ```bash
   ./install.sh
   ```

2. **Initialize configuration:**
   ```bash
   monk init
   ```

3. **Start using:**
   ```bash
   monk --help
   monk auth login <tenant> <username>
   ```

## Installation

The easiest way to install:
```bash
git clone https://github.com/ianzepp/monk-cli.git
cd monk-cli
./install.sh
```

This will:
- Build the CLI using bashly
- Install to `~/.local/bin/monk` (user installation) or `/usr/local/bin/monk` (system-wide)
- Make the `monk` command available globally

**Note:** If you see "command not found" after installation, add `~/.local/bin` to your PATH:
```bash
echo 'export PATH="$PATH:$HOME/.local/bin"' >> ~/.bashrc
source ~/.bashrc
```

## Manual Build

If you need to build manually:
```bash
gem install bashly
./build.sh
./monk --help
```

## Development

The CLI is built using [bashly](https://bashly.dannyb.co/). Source files are in `src/`:
- `src/bashly.yml` - Main configuration and command definitions
- `src/lib/` - Shared library functions
- `src/*_command.sh` - Individual command implementations

To rebuild after changes:
```bash
bashly generate
```