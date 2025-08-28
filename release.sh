#!/bin/bash

# release.sh - Complete release workflow
# Usage: ./release.sh [version]
# Updates version, rebuilds binary, creates versioned release, and tags

set -e

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
RED='\033[0;31m'
NC='\033[0m' # No Color

# Get version argument or auto-increment
if [ -n "$1" ]; then
    version="$1"
else
    # Auto-increment minor version
    current_version=$(grep "version:" src/bashly.yml | awk '{print $2}')
    if [[ "$current_version" =~ ^([0-9]+)\.([0-9]+)\.([0-9]+)$ ]]; then
        major="${BASH_REMATCH[1]}"
        minor="${BASH_REMATCH[2]}"
        patch="${BASH_REMATCH[3]}"
        new_minor=$((minor + 1))
        version="${major}.${new_minor}.0"
    else
        echo -e "${RED}✗${NC} Could not parse current version: $current_version"
        echo "Usage: $0 [version]"
        exit 1
    fi
fi

echo -e "${BLUE}Creating release for version ${version}...${NC}"

# Validate version format
if [[ ! "$version" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
    echo -e "${RED}✗${NC} Invalid version format: $version"
    echo "Version must be in format X.Y.Z (e.g., 2.3.0)"
    exit 1
fi

# Check if version already exists
if [[ -f "bin/monk-${version}" ]]; then
    echo -e "${YELLOW}⚠${NC} Version $version already exists"
    echo -e "${YELLOW}→${NC} Use a different version or delete bin/monk-${version} first"
    exit 1
fi

# Update version in bashly.yml
echo -e "${YELLOW}→${NC} Updating version in src/bashly.yml to ${version}"
sed -i.bak "s/^version: .*/version: ${version}/" src/bashly.yml
rm src/bashly.yml.bak

# Rebuild binary with new version
echo -e "${YELLOW}→${NC} Rebuilding binary with version ${version}"
if ! ./rebuild.sh; then
    echo -e "${RED}✗${NC} Failed to rebuild binary"
    echo "Make sure bashly is installed and try again"
    exit 1
fi

# Verify the binary has correct version
binary_version=$(bin/monk --version)
if [[ "$binary_version" != "$version" ]]; then
    echo -e "${RED}✗${NC} Binary version ($binary_version) doesn't match expected version ($version)"
    echo "Something went wrong during rebuild"
    exit 1
fi

echo -e "${GREEN}✓${NC} Binary rebuilt with version ${version}"

# Create versioned binary
versioned_binary="bin/monk-${version}"
if [[ -f "$versioned_binary" ]]; then
    echo -e "${YELLOW}⚠${NC} Version $version already exists at $versioned_binary"
    echo -e "${YELLOW}→${NC} Overwriting existing version"
fi

cp bin/monk "$versioned_binary"
chmod +x "$versioned_binary"

echo -e "${GREEN}✓${NC} Created release binary: $versioned_binary"

# List all available versions
echo
echo -e "${BLUE}Available versions in bin/:${NC}"
ls -la bin/monk-* 2>/dev/null | awk '{print "  " $9 " (" $5 " bytes, " $6 " " $7 " " $8 ")"}' || echo "  No versioned binaries found"

echo
echo -e "${GREEN}✓${NC} Release v${version} ready!"

# Commit changes
echo -e "${YELLOW}→${NC} Committing release changes..."
git add src/bashly.yml bin/monk-${version}
git commit -m "Release v${version}

- Updated version in src/bashly.yml to ${version}
- Added versioned binary bin/monk-${version}
- Ready for distribution to end users

🤖 Generated with [Claude Code](https://claude.ai/code)

Co-Authored-By: Claude <noreply@anthropic.com>"

# Create and push tag
echo -e "${YELLOW}→${NC} Creating and pushing tag v${version}..."
git tag v${version}
git push && git push --tags

echo -e "${GREEN}✓${NC} Release v${version} complete and deployed!"
echo
echo "Release Summary:"
echo "  • Version: ${version}"
echo "  • Binary: bin/monk-${version}"
echo "  • Tag: v${version}"
echo "  • Status: Deployed to repository"
echo
echo "End users can now install with:"
echo "  ./install.sh ${version}"