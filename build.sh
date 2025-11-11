#!/bin/bash

# Build script for monk CLI
# Requires bashly to be installed

set -e

echo "Building Monk CLI..."

# Check if bashly is available
if ! command -v bashly &> /dev/null; then
    if [ -f "/home/ianzepp/.local/share/gem/ruby/3.2.0/bin/bashly" ]; then
        echo "Using bashly from user gem directory..."
        BASHLY="/home/ianzepp/.local/share/gem/ruby/3.2.0/bin/bashly"
    else
        echo "Error: bashly not found. Please install with: gem install bashly"
        exit 1
    fi
else
    BASHLY="bashly"
fi

# Generate the CLI
$BASHLY generate

# Fix exit code for root command fallback (show help with exit 0 instead of 1)
# This changes the exit code from 1 to 0 when no command is provided (shows help)
awk '
/# :command\.command_fallback/ { in_fallback = 1 }
in_fallback && /exit 1/ { sub(/exit 1/, "exit 0"); in_fallback = 0 }
{ print }
' monk > monk.tmp && mv monk.tmp monk

# Make executable
chmod +x ./monk

echo "✓ CLI built successfully!"
echo "Run './monk --help' to test the CLI"