# Check dependencies
check_dependencies

# Initialize CLI configs
init_cli_configs

if ! command -v jq >/dev/null 2>&1; then
    print_error "jq is required for template listing"
    exit 1
fi

base_url=$(get_base_url)

print_info "Fetching available templates from: ${base_url}/auth/templates"

# Make request to list templates
if response=$(make_request_json "GET" "/auth/templates" ""); then
    # Determine output format from global flags
    output_format=$(get_output_format "text")

    if [[ "$output_format" == "text" ]]; then
        # Human-readable table output
        templates=$(echo "$response" | jq -r '.data')
        count=$(echo "$templates" | jq 'length')

        echo
        print_info "Available templates: $count"
        echo

        if [[ "$count" -gt 0 ]]; then
            printf "%-20s %-60s\n" "NAME" "DESCRIPTION"
            echo "--------------------------------------------------------------------------------"

            echo "$templates" | jq -r '.[] | [.name, (.description // "-")] | @tsv' | \
            while IFS=$'\t' read -r name description; do
                printf "%-20s %-60s\n" "$name" "$description"
            done
        else
            print_info "No templates found"
        fi
        echo
    else
        # JSON output - pass through compact JSON
        handle_output "$response" "$output_format" "json"
    fi
else
    print_error "Failed to retrieve templates"
    print_info "This endpoint is only available when the server is running in personal mode"
    exit 1
fi
