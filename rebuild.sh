#!/bin/bash

# rebuild.sh - Development build script for monk CLI
# This script is for developers who need to rebuild the CLI after making changes
# End users should use the prebuilt monk binary and ./install.sh

set -e

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
RED='\033[0;31m'
NC='\033[0m' # No Color

echo -e "${BLUE}Rebuilding Monk CLI...${NC}"

# Check if bashly is available
if ! command -v bashly &> /dev/null; then
    if [ -f "/home/ianzepp/.local/share/gem/ruby/3.2.0/bin/bashly" ]; then
        echo -e "${YELLOW}→${NC} Using bashly from user gem directory..."
        BASHLY="/home/ianzepp/.local/share/gem/ruby/3.2.0/bin/bashly"
    else
        echo -e "${RED}✗${NC} bashly not found. Please install with: gem install bashly"
        echo -e "${YELLOW}ℹ${NC} This script is for developers. End users should use the prebuilt monk binary."
        exit 1
    fi
else
    BASHLY="bashly"
fi

# Create bin directory if it doesn't exist
mkdir -p bin

# Generate the CLI to bin/monk
echo -e "${YELLOW}→${NC} Generating CLI with bashly..."
$BASHLY generate

# Move to bin directory and make executable
mv ./monk bin/monk
chmod +x bin/monk

# Show version
version=$(bin/monk --version)
echo -e "${GREEN}✓${NC} CLI rebuilt successfully! Version: ${version}"
echo -e "${GREEN}✓${NC} Binary created at: bin/monk"
echo
echo "Next steps:"
echo "  • Test locally: bin/monk --help"
echo "  • Install locally: ./install.sh" 
echo "  • Create release: ./release.sh ${version}"
echo "  • Commit changes: git add bin/ && git commit -m 'Update to v${version}'"
echo
echo -e "${YELLOW}Note:${NC} Use ./release.sh to create versioned binaries for releases"