#!/bin/bash

# auth_info_command.sh - Decode and display JWT token contents with universal format support

# Determine output format from global flags
output_format=$(get_output_format "text")

token=$(get_jwt_token)

if [ -z "$token" ]; then
    error_result='{"error": "No authentication token found", "message": "Use monk auth login TENANT USERNAME to authenticate"}'
    
    if [[ "$output_format" == "text" ]]; then
        print_error "No authentication token found"
        print_info "Use 'monk auth login TENANT USERNAME' to authenticate"
    else
        handle_output "$error_result" "$output_format" "json"
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
    error_result='{"error": "base64 command not found"}'
    
    if [[ "$output_format" == "text" ]]; then
        print_error "base64 command not found"
    else
        handle_output "$error_result" "$output_format" "json"
    fi
    exit 1
fi

if [ -n "$decoded" ]; then
    if command -v jq >/dev/null 2>&1; then
        # Add computed fields to the token payload for JSON output
        exp_timestamp=$(echo "$decoded" | jq -r '.exp' 2>/dev/null)
        exp_date=""
        if [ "$exp_timestamp" != "null" ] && [ -n "$exp_timestamp" ]; then
            exp_date=$(date -r "$exp_timestamp" 2>/dev/null || echo 'unknown')
        fi
        
        # Build enhanced token info JSON
        token_info=$(echo "$decoded" | jq --arg exp_date "$exp_date" \
            '. + {
                exp_date: (if $exp_date == "" or $exp_date == "unknown" then null else $exp_date end),
                token_valid: true
            }')
        
        if [[ "$output_format" == "text" ]]; then
            # Human-readable output
            print_success "JWT Token Information:"
            echo
            
            # Extract key fields for display
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
                echo "Expires At: $exp_date"
            fi
            
            echo
        else
            handle_output "$token_info" "$output_format" "json"
        fi
    else
        # Fallback without jq
        fallback_result='{"error": "jq required for token parsing", "raw_payload": "'"$decoded"'"}'
        
        if [[ "$output_format" == "text" ]]; then
            print_error "jq required for token parsing"
            echo "Raw payload: $decoded"
        else
            handle_output "$fallback_result" "$output_format" "json"
        fi
    fi
else
    decode_error='{"error": "Failed to decode JWT token", "message": "Token may be malformed"}'
    
    if [[ "$output_format" == "text" ]]; then
        print_error "Failed to decode JWT token"
        print_info "Token may be malformed"
    else
        handle_output "$decode_error" "$output_format" "json"
    fi
    exit 1
fi