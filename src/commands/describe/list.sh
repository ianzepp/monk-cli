#!/bin/bash

# describe_list_command.sh - List all available schema names
#
# This command retrieves all schema names available in the current tenant.
#
# Usage Examples:
#   monk describe list                    # List all schemas
#   monk --format=json describe list      # JSON format
#   monk --format=yaml describe list      # YAML format
#   monk --format=csv describe list       # CSV format
#
# Output Format:
#   - Controlled by --format flag (or API default)
#   - API handles all formatting
#
# API Endpoint:
#   GET /api/describe (returns array of schema names)

# Check dependencies
check_dependencies

print_info "Listing all available schemas"

response=$(make_request_json "GET" "/api/describe" "")

# Output response directly (API handles formatting)
echo "$response"
