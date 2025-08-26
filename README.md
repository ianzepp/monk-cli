# Monk CLI

Command-line interface for the Monk API - a bashly-based CLI tool.

## Installation

```bash
gem install bashly
```

## Usage

Build the CLI:
```bash
bashly generate
```

Run commands:
```bash
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