#!/bin/bash

# Installation script for Monk CLI
# Installs the prebuilt monk command globally
# End users should NOT need to install bashly - use the prebuilt binary

set -e

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
RED='\033[0;31m'
NC='\033[0m' # No Color

echo -e "${BLUE}Installing Monk CLI...${NC}"

# Check if prebuilt monk binary exists
if [[ ! -f "./monk" ]]; then
    echo -e "${RED}✗${NC} Prebuilt monk binary not found"
    echo -e "${YELLOW}ℹ${NC} This repository should include a prebuilt monk binary"
    echo -e "${YELLOW}ℹ${NC} If you're a developer, run ./rebuild.sh first"
    echo -e "${YELLOW}ℹ${NC} If you're an end user, please report this issue"
    exit 1
fi

# Verify the binary is executable and working
if ! ./monk --version >/dev/null 2>&1; then
    echo -e "${RED}✗${NC} Prebuilt monk binary is not working correctly"
    echo -e "${YELLOW}ℹ${NC} Please report this issue or contact support"
    exit 1
fi

version=$(./monk --version)
echo -e "${YELLOW}ℹ${NC} Installing Monk CLI version: ${version}"

# Determine installation directory
if [[ "$EUID" -eq 0 ]] || [[ -w "/usr/local/bin" ]]; then
    # System-wide installation
    INSTALL_DIR="/usr/local/bin"
    echo -e "${YELLOW}→${NC} Installing system-wide to ${INSTALL_DIR}"
else
    # User installation
    INSTALL_DIR="$HOME/.local/bin"
    echo -e "${YELLOW}→${NC} Installing to user directory ${INSTALL_DIR}"
    
    # Create directory if it doesn't exist
    mkdir -p "$INSTALL_DIR"
    
    # Check if ~/.local/bin is in PATH
    if [[ ":$PATH:" != *":$HOME/.local/bin:"* ]]; then
        echo -e "${YELLOW}⚠${NC}  Warning: $HOME/.local/bin is not in your PATH"
        echo "   Add this to your ~/.bashrc or ~/.zshrc:"
        echo "   export PATH=\"\$PATH:\$HOME/.local/bin\""
    fi
fi

# Copy the monk executable
cp "./monk" "$INSTALL_DIR/monk"
chmod +x "$INSTALL_DIR/monk"

echo -e "${GREEN}✓${NC} Monk CLI installed successfully!"
echo
echo "Usage:"
echo "  monk --help              # Show all commands"
echo "  monk init                # Initialize configuration"
echo "  monk server add <name> <host:port>  # Add server"
echo "  monk tenant add <name> <display>    # Add tenant"
echo "  monk auth login <tenant> <user>     # Authenticate"
echo
echo "Installed to: ${INSTALL_DIR}/monk"

# Test the installation
if command -v monk >/dev/null 2>&1; then
    echo -e "${GREEN}✓${NC} 'monk' command is available globally"
    echo -e "${GREEN}✓${NC} Monk CLI v${version} ready to use!"
else
    echo -e "${YELLOW}⚠${NC}  'monk' command not found in PATH"
    echo "   You may need to restart your shell or update your PATH"
fi