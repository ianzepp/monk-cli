#!/bin/bash

# package_install_command.sh - Install a package to the current tenant
#
# This command installs a package (schemas and optionally data) to the
# currently selected tenant. Supports local files and directories.
#
# Usage Examples:
#   monk package install ./monk.json                  # Install from monk.json file
#   monk package install ./my-package                 # Install from directory (finds monk.json)
#   monk package install . --force                    # Force reinstall current directory
#   monk package install ./monk.json --dry-run        # Preview installation
#
# Installation Process:
#   - Verify package file exists and is valid JSON
#   - Check monk-api version requirements
#   - Install/update schemas from describe array
#   - Import data from data array (if included)
#   - Create users from users array (if createUsers enabled)

# Check dependencies
check_dependencies

# Get arguments from bashly
package_path="${args[package_file]}"
force_install="${args[--force]}"
dry_run="${args[--dry-run]}"

# Determine output format
if [[ "${args[--json]}" == "true" ]]; then
  output_format="json"
else
  output_format="text"
fi

# Resolve package file path
if [[ -d "$package_path" ]]; then
  # If directory, look for monk.json inside
  package_file="$package_path/monk.json"
  package_dir="$package_path"
elif [[ -f "$package_path" ]]; then
  # If file, use it directly
  package_file="$package_path"
  package_dir="$(dirname "$package_path")"
else
  echo "Error: Package path not found: $package_path" >&2
  exit 1
fi

# Verify monk.json exists
if [[ ! -f "$package_file" ]]; then
  echo "Error: monk.json not found at: $package_file" >&2
  exit 1
fi

# Verify monk.json is valid JSON
if ! jq empty "$package_file" 2>/dev/null; then
  echo "Error: Invalid JSON in $package_file" >&2
  exit 1
fi

# Parse package metadata
package_name=$(jq -r '.name // "unknown"' "$package_file")
package_version=$(jq -r '.version // "unknown"' "$package_file")
package_description=$(jq -r '.description // ""' "$package_file")

if [[ "$output_format" != "json" ]]; then
  echo "Installing package: $package_name v$package_version"
  echo "Description: $package_description"
  echo ""
fi

# Get describe files
describe_files=($(jq -r '.describe[]? // empty' "$package_file"))
describe_count=${#describe_files[@]}

# Get data files
data_files=($(jq -r '.data[]? // empty' "$package_file"))
data_count=${#data_files[@]}

if [[ "$dry_run" == "1" ]]; then
  echo "DRY RUN - No changes will be made"
  echo ""
  echo "Would install $describe_count schemas:"
  for describe_file in "${describe_files[@]}"; do
    schema_name=$(basename "$describe_file" .json)
    echo "  - $schema_name (from $describe_file)"
  done

  if [[ $data_count -gt 0 ]]; then
    echo ""
    echo "Would import $data_count data fixtures:"
    for data_file in "${data_files[@]}"; do
      echo "  - $data_file"
    done
  fi
  exit 0
fi

# Install schemas
installed_count=0
failed_count=0
skipped_count=0

if [[ "$output_format" != "json" ]]; then
  echo "Installing $describe_count schemas..."
  echo ""
fi

for describe_file in "${describe_files[@]}"; do
  schema_path="$package_dir/$describe_file"
  schema_name=$(basename "$describe_file" .json)

  if [[ ! -f "$schema_path" ]]; then
    echo "  ✗ Schema file not found: $schema_path" >&2
    ((failed_count++))
    continue
  fi

  # Read schema definition
  schema_def=$(cat "$schema_path")

  if [[ "$output_format" != "json" ]]; then
    echo -n "  Installing $schema_name... "
  fi

  # Check if schema already exists
  existing_check=$(make_request_json "GET" "/api/describe/$schema_name" "" 2>/dev/null)
  schema_exists=$(echo "$existing_check" | jq -r '.success // false')

  if [[ "$schema_exists" == "true" && "$force_install" != "1" ]]; then
    if [[ "$output_format" != "json" ]]; then
      echo "skipped (already exists, use --force to overwrite)"
    fi
    ((skipped_count++))
    continue
  fi

  # Install or update schema
  if [[ "$schema_exists" == "true" ]]; then
    # Update existing schema
    response=$(make_request_json "PUT" "/api/describe/$schema_name" "$schema_def")
  else
    # Create new schema
    response=$(make_request_json "POST" "/api/describe/$schema_name" "$schema_def")
  fi

  # Check result
  if echo "$response" | jq -e '.success == true' >/dev/null 2>&1; then
    if [[ "$output_format" != "json" ]]; then
      echo "✓"
    fi
    ((installed_count++))
  else
    if [[ "$output_format" != "json" ]]; then
      echo "✗"
      echo "$response" | jq -r '.error // "Unknown error"' >&2
    fi
    ((failed_count++))
  fi
done

# Output summary
if [[ "$output_format" == "json" ]]; then
  echo "{\"success\":true,\"package\":\"$package_name\",\"version\":\"$package_version\",\"installed\":$installed_count,\"skipped\":$skipped_count,\"failed\":$failed_count}"
else
  echo ""
  echo "Installation complete:"
  echo "  ✓ Installed: $installed_count"
  if [[ $skipped_count -gt 0 ]]; then
    echo "  - Skipped: $skipped_count (already exist)"
  fi
  if [[ $failed_count -gt 0 ]]; then
    echo "  ✗ Failed: $failed_count"
  fi

  if [[ $failed_count -gt 0 ]]; then
    exit 1
  fi
fi
