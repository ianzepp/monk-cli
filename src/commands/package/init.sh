#!/bin/bash

# package_init_command.sh - Initialize a new package definition
#
# This command creates a monk.json file with schema definitions and metadata
# for distributing and installing schema packages across tenants.
#
# Usage Examples:
#   monk package init                           # Create monk.json from current directory
#   monk package init my-app                    # Create monk.json named 'my-app'
#   monk package init --description "My App"    # Add description to package
#
# Output:
#   Creates monk.json in current directory with:
#   - Package metadata (name, version, description, author, license)
#   - Requirements for monk-api version
#   - Schema, fixture, and user file references
#   - Installation configuration
#   - Dependencies on other packages

# Check dependencies
check_dependencies

# Get arguments from bashly
package_name="${args[name]}"
description="${args[--description]:-}"

# Determine output format
if [[ "${args[--json]}" == "true" ]]; then
  output_format="json"
else
  output_format="text"
fi

# Default package name to current directory name if not provided
if [[ -z "$package_name" ]]; then
  package_name=$(basename "$PWD")
fi

# Check if monk.json already exists
if [[ -f "monk.json" ]]; then
  echo "Error: monk.json already exists in current directory" >&2
  echo "Remove it first or use a different directory" >&2
  exit 1
fi

# Get git config for author information (fallback to defaults)
git_name=$(git config user.name 2>/dev/null || echo "Your Name")
git_email=$(git config user.email 2>/dev/null || echo "your.email@example.com")
author="$git_name <$git_email>"

# Default description if not provided
if [[ -z "$description" ]]; then
  description="Package description for $package_name"
fi

# Create monk.json with template structure
cat > monk.json <<EOF
{
  "name": "$package_name",
  "version": "1.0.0",
  "description": "$description",
  "author": "$author",
  "license": "MIT",
  "homepage": "https://github.com/your-org/$package_name",

  "requirements": {
    "monk-api": ">=2.0.0"
  },

  "schemas": [
  ],

  "fixtures": [
  ],

  "users": [
  ],

  "install": {
    "createUsers": true,
    "importFixtures": false,
    "mergeSchemas": true,
    "skipExisting": false
  },

  "dependencies": {
  }
}
EOF

# Output success message
if [[ "$output_format" == "json" ]]; then
  echo "{\"success\":true,\"file\":\"monk.json\",\"name\":\"$package_name\",\"version\":\"1.0.0\"}"
else
  echo "Created monk.json for package '$package_name'"
  echo ""
  echo "Package structure:"
  echo "  Name: $package_name"
  echo "  Version: 1.0.0"
  echo "  Description: $description"
  echo "  Author: $author"
  echo ""
  echo "Next steps:"
  echo "  1. Edit monk.json to add your schemas, fixtures, and users"
  echo "  2. Create schema files in schemas/ directory"
  echo "  3. Create fixture files in fixtures/ directory (optional)"
  echo "  4. Create user files in users/ directory (optional)"
  echo "  5. Run 'monk package verify' to validate your package"
fi
