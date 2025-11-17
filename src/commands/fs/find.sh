#!/bin/bash

# fs_find_command.sh - Find files with content filtering (Unix find-like)

# Check dependencies
check_dependencies

# Get arguments from bashly
path="${args[path]}"
where_flags=("${args[--where]}")
type_flag="${args[--type]}"
name_flag="${args[--name]}"
maxdepth_flag="${args[--maxdepth]}"
print0_flag="${args[--print0]}"
flat_flag="${args[--flat]}"
tenant_flag="${args[--tenant]}"

print_info "Searching: $path"

# Build WHERE clause from multiple -w/--where flags
where_clause="{}"

if [ ${#where_flags[@]} -gt 0 ]; then
    for condition in "${where_flags[@]}"; do
        if [ -z "$condition" ] || [ "$condition" = "null" ]; then
            continue
        fi

        # Unescape if needed (bashly may escape JSON)
        unescaped_condition="$condition"
        if [[ "$condition" == "\\"* ]]; then
            unescaped_condition=$(echo "$condition" | sed 's/\\//g')
        fi

        if [[ "$unescaped_condition" == "{"* ]]; then
            # JSON format - merge it
            where_clause=$(echo "$where_clause" | jq --argjson new "$unescaped_condition" '. * $new')
        elif [[ "$condition" == *"="* ]]; then
            # key=value format
            key="${condition%%=*}"
            value="${condition#*=}"
            where_clause=$(echo "$where_clause" | jq --arg k "$key" --arg v "$value" '.[$k] = $v')
        else
            print_error "Invalid -where format: $condition"
            print_info "Use: -where key=value  OR  -where '{\"key\":\"value\"}'"
            exit 1
        fi
    done

    # Check if we actually have filters
    if [ "$where_clause" != "{}" ]; then
        print_info "Content filter: $(echo "$where_clause" | jq -c .)"
    fi
fi

# Build file options
file_options_parts=()

# Add recursive search (always on for find)
file_options_parts+=("\"recursive\": true")

# Flat listing (files only) when requested
if [ "$flat_flag" = "1" ]; then
    file_options_parts+=("\"flat\": true")
    print_info "Flattening results to files only"
fi

# Add max_depth if specified
if [ -n "$maxdepth_flag" ]; then
    file_options_parts+=("\"max_depth\": $maxdepth_flag")
    print_info "Max depth: $maxdepth_flag"
fi

# Add WHERE clause if we have one
if [ "$where_clause" != "{}" ]; then
    where_json=$(echo "$where_clause" | jq -c .)
    file_options_parts+=("\"where\": $where_json")
fi

# Build complete file_options JSON
file_options=$(printf '{%s}' "$(IFS=,; echo "${file_options_parts[*]}")")

# Make request with tenant routing
response=$(make_file_request_with_routing "list" "$path" "$file_options" "$tenant_flag")

# Extract entries
entries=$(process_file_response "$response" "entries")

if [ -z "$entries" ] || [ "$entries" = "null" ]; then
    print_info "No matches found"
    exit 0
fi

# Client-side filtering (for options not supported by API yet)

# Filter by type if specified
if [ -n "$type_flag" ]; then
    print_info "Filtering by type: $type_flag"
    entries=$(echo "$entries" | jq --arg type "$type_flag" '[.[] | select(.file_type == $type)]')
fi

# Filter by name pattern if specified
if [ -n "$name_flag" ]; then
    print_info "Filtering by name: $name_flag"
    # Convert wildcard pattern to regex
    regex_pattern=$(echo "$name_flag" | sed 's/\*/.*/' | sed 's/?/./')
    entries=$(echo "$entries" | jq --arg pattern "^${regex_pattern}$" '[.[] | select(.name | test($pattern))]')
fi

# Output results
if [ "$print0_flag" = "1" ]; then
    # Null-separated output for xargs -0
    echo "$entries" | jq -r '.[].path' | tr '\n' '\0'
else
    # Normal output (one path per line)
    echo "$entries" | jq -r '.[].path'
fi

# Print count if verbose
count=$(echo "$entries" | jq 'length')
if [ "$count" = "0" ]; then
    print_info "No matches found"
else
    print_success "Found $count matches"
fi
