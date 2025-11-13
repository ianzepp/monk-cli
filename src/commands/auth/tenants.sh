# Check dependencies
check_dependencies

# Initialize CLI configs
init_cli_configs

if ! command -v jq >/dev/null 2>&1; then
    print_error "jq is required for tenant listing"
    exit 1
fi

base_url=$(get_base_url)

print_info "Fetching available tenants from: ${base_url}/auth/tenants"

# Make request to list tenants
if response=$(make_request_json "GET" "/auth/tenants" ""); then
    # Determine output format from global flags
    output_format=$(get_output_format "text")
    
    if [[ "$output_format" == "text" ]]; then
        # Human-readable table output
        tenants=$(echo "$response" | jq -r '.data')
        count=$(echo "$tenants" | jq 'length')
        
        echo
        print_info "Available tenants: $count"
        echo
        
        if [[ "$count" -gt 0 ]]; then
            printf "%-25s %-35s %-30s\n" "NAME" "DESCRIPTION" "USERS"
            echo "--------------------------------------------------------------------------------"
            
            echo "$tenants" | jq -r '.[] | [.name, (.description // "-"), (.users | join(", "))] | @tsv' | \
            while IFS=$'\t' read -r name description users; do
                printf "%-25s %-35s %-30s\n" "$name" "$description" "$users"
            done
        else
            print_info "No tenants found"
        fi
        echo
    else
        # JSON output - pass through compact JSON
        handle_output "$response" "$output_format" "json"
    fi
else
    print_error "Failed to retrieve tenants"
    print_info "This endpoint is only available when the server is running in personal mode"
    exit 1
fi
