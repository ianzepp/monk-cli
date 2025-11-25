#!/bin/bash

# package_describe_add_command.sh - Add schema definition to package
#
# This command fetches a schema definition from the current tenant and adds it
# to the package by saving it to describe/<schema>.json and updating monk.json.
#
# Usage Examples:
#   monk package describe add users                    # Add users schema to package
#   monk package describe add bot_conversations        # Add bot_conversations schema
#   monk package describe add users --force            # Overwrite existing file
#
# Process:
#   1. Verify monk.json exists in current directory
#   2. Fetch schema definition from current tenant via API
#   3. Create describe/ directory if needed
#   4. Save schema to describe/<schema>.json
#   5. Add entry to monk.json describe array
#
# Requirements:
#   - monk.json must exist in current directory
#   - Must be authenticated to a tenant
#   - Schema must exist in current tenant

# Check dependencies
check_dependencies

# Get arguments from bashly
schema="${args[model]}"
force="${args[--force]:-false}"

# Determine output format
if [[ "${args[--json]}" == "true" ]]; then
  output_format="json"
else
  output_format="text"
fi

# Validate monk.json exists
if [[ ! -f "monk.json" ]]; then
  echo "Error: monk.json not found in current directory" >&2
  echo "Run 'monk package init' to create a package first" >&2
  exit 1
fi

# Validate monk.json is valid JSON
if ! jq empty monk.json 2>/dev/null; then
  echo "Error: monk.json is not valid JSON" >&2
  exit 1
fi

# Define paths
describe_dir="describe"
schema_file="$describe_dir/$schema.json"
monk_json_entry="describe/$schema.json"

# Check if file already exists (unless --force)
if [[ -f "$schema_file" && "${args[--force]}" != "1" ]]; then
  echo "Error: $schema_file already exists" >&2
  echo "Use --force to overwrite" >&2
  exit 1
fi

# Fetch schema definition from current tenant
if [[ "$output_format" != "json" ]]; then
  print_info "Fetching schema '$schema' from current tenant..."
fi

response=$(make_request_json "GET" "/api/describe/$schema" "")

# Check if request was successful
if ! echo "$response" | jq -e '.success == true' >/dev/null 2>&1; then
  echo "Error: Failed to fetch schema '$schema'" >&2
  handle_response_json "$response" "fetch"
  exit 1
fi

# Extract schema definition
schema_data=$(echo "$response" | jq -r '.data')

# Create describe directory if it doesn't exist
mkdir -p "$describe_dir"

# Save schema to file
echo "$schema_data" | jq . > "$schema_file"

# Add to monk.json describe array if not already present
if ! jq -e --arg entry "$monk_json_entry" '.describe | index($entry)' monk.json >/dev/null 2>&1; then
  # Entry doesn't exist, add it
  jq --arg entry "$monk_json_entry" '.describe += [$entry]' monk.json > monk.json.tmp
  mv monk.json.tmp monk.json
  added_to_manifest="true"
else
  added_to_manifest="false"
fi

# Output success message
if [[ "$output_format" == "json" ]]; then
  echo "{\"success\":true,\"schema\":\"$schema\",\"file\":\"$schema_file\",\"added_to_manifest\":$added_to_manifest}"
else
  echo "✓ Schema '$schema' added to package"
  echo ""
  echo "  Saved to: $schema_file"
  if [[ "$added_to_manifest" == "true" ]]; then
    echo "  Added to: monk.json describe array"
  else
    echo "  Already in: monk.json describe array"
  fi
  echo ""
  echo "Next steps:"
  echo "  - Review the schema definition in $schema_file"
  echo "  - Add more schemas: monk package describe add <schema>"
  echo "  - Verify package: monk package verify"
fi
