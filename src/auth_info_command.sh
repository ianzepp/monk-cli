# Get arguments from bashly
json_flag="${args[--json]}"

token=$(get_jwt_token)

if [ -z "$token" ]; then
    if [ "$json_flag" = "1" ]; then
        echo '{"error": "No authentication token found", "message": "Use monk auth login TENANT USERNAME to authenticate"}'
    else
        print_error "No authentication token found"
        print_info "Use 'monk auth login TENANT USERNAME' to authenticate"
    fi
    exit 1
fi

# Extract payload (second part) from JWT
payload=$(echo "$token" | cut -d'.' -f2)

# Add padding if needed for base64 decoding
padding=$((4 - ${#payload} % 4))
if [ $padding -ne 4 ]; then
    payload="${payload}$(printf '%*s' $padding '' | tr ' ' '=')"
fi

# Decode base64 payload
if command -v base64 >/dev/null 2>&1; then
    decoded=$(echo "$payload" | base64 -d 2>/dev/null || echo "")
else
    print_error "base64 command not found"
    exit 1
fi

if [ -n "$decoded" ]; then
    if [ "$json_flag" = "1" ]; then
        # JSON output mode - return the decoded JWT payload with additional metadata
        if command -v jq >/dev/null 2>&1; then
            exp_timestamp=$(echo "$decoded" | jq -r '.exp' 2>/dev/null)
            exp_date=""
            if [ "$exp_timestamp" != "null" ] && [ -n "$exp_timestamp" ]; then
                exp_date=$(date -r "$exp_timestamp" 2>/dev/null || echo 'unknown')
            fi
            
            # Add computed fields to the token payload
            echo "$decoded" | jq --arg exp_date "$exp_date" \
                '. + {
                    exp_date: (if $exp_date == "" or $exp_date == "unknown" then null else $exp_date end),
                    token_valid: true
                }'
        else
            # Fallback if jq not available
            echo '{"error": "jq required for JSON mode", "raw_payload": "'"$decoded"'"}'
        fi
    else
        # Human-readable output mode
        print_success "JWT Token Information:"
        echo
        
        if command -v jq >/dev/null 2>&1; then
            # Extract key fields for human-readable display
            sub=$(echo "$decoded" | jq -r '.sub // "unknown"' 2>/dev/null)
            name=$(echo "$decoded" | jq -r '.name // "unknown"' 2>/dev/null)
            tenant=$(echo "$decoded" | jq -r '.tenant // "unknown"' 2>/dev/null)
            database=$(echo "$decoded" | jq -r '.database // "unknown"' 2>/dev/null)
            access=$(echo "$decoded" | jq -r '.access // "unknown"' 2>/dev/null)
            iat=$(echo "$decoded" | jq -r '.iat // "unknown"' 2>/dev/null)
            exp=$(echo "$decoded" | jq -r '.exp // "unknown"' 2>/dev/null)
            
            echo "Subject: $sub"
            echo "Name: $name" 
            echo "Tenant: $tenant"
            echo "Database: $database"
            echo "Access Level: $access"
            
            if [ "$iat" != "unknown" ] && [ "$iat" != "null" ]; then
                iat_date=$(date -r "$iat" 2>/dev/null || echo 'unknown')
                echo "Issued At: $iat_date"
            fi
            
            if [ "$exp" != "unknown" ] && [ "$exp" != "null" ]; then
                exp_date=$(date -r "$exp" 2>/dev/null || echo 'unknown')
                echo "Expires: $exp_date"
            fi
        else
            # Fallback if jq not available - show raw JSON
            echo "$decoded"
        fi
    fi
else
    if [ "$json_flag" = "1" ]; then
        echo '{"error": "Failed to decode JWT token", "token_valid": false}'
    else
        print_error "Failed to decode JWT token"
    fi
    exit 1
fi