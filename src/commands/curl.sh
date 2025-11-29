#!/bin/bash

# curl_command.sh - Wrapper for making authenticated API requests

# Check dependencies
check_dependencies

# Get arguments from bashly
method="${args[method]^^}"  # Uppercase the HTTP method
path="${args[path]}"
data_flag="${args[--data]}"
raw_flag="${args[--raw]}"

# Check if the requested format is binary (cannot be captured in a shell variable)
format="${args[--format]:-}"
is_binary_format() {
    case "$1" in
        sqlite|msgpack|cbor|protobuf|avro|parquet|bson)
            return 0
            ;;
        *)
            return 1
            ;;
    esac
}

binary_mode=false
if is_binary_format "$format"; then
    binary_mode=true
    print_info "Binary format detected ($format) - streaming directly to stdout"
fi

# Get base URL (this validates server config exists)
base_url=$(get_base_url)
if [ -z "$base_url" ]; then
    print_error "Could not determine server endpoint"
    print_info "Use 'monk server add <name> <endpoint>' to configure a server"
    exit 1
fi

# Get JWT token if available (authentication is optional)
jwt_token=$(get_jwt_token) || true
if [ -z "$jwt_token" ]; then
    print_info "No authentication token found - making unauthenticated request"
fi

# Construct full URL
# Remove trailing slash from base URL, remove leading slash from path if present
base_url="${base_url%/}"
path="${path#/}"

# Build query string from global flags (--format, --unwrap, --select)
query_string=$(build_api_query_string)

# Combine path with query string
if [ -n "$query_string" ]; then
    full_url="${base_url}/${path}${query_string}"
else
    full_url="${base_url}/${path}"
fi

print_info "Request: $method $full_url"

# Determine request body source
if [ -n "$data_flag" ]; then
    # Use --data flag
    request_body="$data_flag"
    print_info "Using data from --data flag"
elif [ ! -t 0 ]; then
    # Read from stdin (pipe or redirect)
    request_body=$(cat)
    print_info "Using data from stdin"
else
    # No body
    request_body=""
fi

# Build curl arguments
curl_args=(-s -X "$method" -H "Content-Type: application/json")
if [ -n "$jwt_token" ]; then
    curl_args+=(-H "Authorization: Bearer $jwt_token")
fi
if [ -n "$request_body" ]; then
    curl_args+=(-d "$request_body")
fi

# For binary formats, stream directly to stdout to preserve binary data
if [ "$binary_mode" = "true" ]; then
    curl "${curl_args[@]}" "$full_url"
    curl_exit=$?
    if [ $curl_exit -ne 0 ]; then
        print_error "curl failed with exit code: $curl_exit"
        exit 1
    fi
    exit 0
fi

# For text formats, capture response to variable
response=$(curl "${curl_args[@]}" "$full_url")
curl_exit=$?
if [ $curl_exit -ne 0 ]; then
    print_error "curl failed with exit code: $curl_exit"
    exit 1
fi

# Output response
if [ "$raw_flag" = "1" ]; then
    # Raw output - use printf to avoid adding trailing newline
    printf '%s' "$response"
else
    # Pretty-print JSON
    if echo "$response" | jq . >/dev/null 2>&1; then
        echo "$response" | jq .

        # Show success/error status from response
        success=$(echo "$response" | jq -r '.success // empty' 2>/dev/null)
        if [ "$success" = "true" ]; then
            print_success "Request completed successfully"
        elif [ "$success" = "false" ]; then
            error_msg=$(echo "$response" | jq -r '.message // .error // "Unknown error"' 2>/dev/null)
            print_error "Request failed: $error_msg"
            exit 1
        fi
    else
        # Not JSON, output as-is
        printf '%s' "$response"
    fi
fi
