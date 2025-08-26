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

# Make executable
chmod +x ./monk

echo "✓ CLI built successfully!"
echo "Run './monk --help' to test the CLI"