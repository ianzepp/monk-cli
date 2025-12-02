# Send prompt to AI agent
# Uses current session authentication to POST to /api/agent

# Capture all arguments as the prompt (allows unquoted multi-word input)
prompt="${other_args[*]}"

# Build JSON payload
json_data=$(jq -n --arg prompt "$prompt" '{"prompt": $prompt}')

print_info "Sending prompt to AI agent: $prompt"

# Streaming mode - request JSONL stream from server
if [[ "${args[--stream]}" ]]; then
    base_url=$(get_base_url)
    jwt_token=$(get_jwt_token)

    # Stream directly from curl and process each JSONL line as it arrives
    curl -s -N -X POST "${base_url}/api/agent" \
        -H "Content-Type: application/json" \
        -H "Accept: text/jsonl" \
        -H "Authorization: Bearer $jwt_token" \
        -d "$json_data" | while IFS= read -r line; do

        # Skip empty lines
        [[ -z "$line" ]] && continue

        # Parse type from JSON line
        type=$(echo "$line" | jq -r '.type // empty' 2>/dev/null)
        [[ -z "$type" ]] && continue

        case "$type" in
            tool_call)
                name=$(echo "$line" | jq -r '.name')
                cmd=$(echo "$line" | jq -r '.input.command // (.input | tostring)')
                echo -e "${YELLOW}→ ${name}:${NC} ${cmd}"
                ;;
            tool_result)
                # Only show output if there was an error
                exit_code=$(echo "$line" | jq -r '.exitCode // 0')
                if [[ "$exit_code" != "0" ]]; then
                    output=$(echo "$line" | jq -r '.output // empty')
                    if [[ -n "$output" ]]; then
                        # Check if this is an API error with JSON - extract key fields
                        if echo "$output" | grep -q "API error:"; then
                            # Extract HTTP code and JSON from "command: API error: NNN {...}"
                            http_code=$(echo "$output" | grep -o 'API error: [0-9]*' | head -1 | grep -o '[0-9]*')
                            json_part=$(echo "$output" | grep -o '{.*}' | head -1)
                            if [[ -n "$json_part" ]]; then
                                err_msg=$(echo "$json_part" | jq -r '.error // empty' 2>/dev/null)
                                err_code=$(echo "$json_part" | jq -r '.error_code // empty' 2>/dev/null)
                                if [[ -n "$err_msg" ]]; then
                                    echo -e "  ${RED}Error ${http_code}: ${err_msg} [${err_code}]${NC}"
                                else
                                    echo -e "  ${RED}Error ${http_code}${NC}"
                                fi
                            else
                                echo -e "  ${RED}API error: ${http_code}${NC}"
                            fi
                        else
                            # Not an API error - show truncated output
                            line_count=$(echo "$output" | wc -l | tr -d ' ')
                            echo "$output" | head -10 | sed 's/^/  /'
                            if [[ $line_count -gt 10 ]]; then
                                echo -e "  ${BLUE}... ($((line_count - 10)) more lines)${NC}"
                            fi
                        fi
                    fi
                fi
                ;;
            text)
                content=$(echo "$line" | jq -r '.content')
                if command -v glow >/dev/null 2>&1; then
                    echo "$content" | glow -
                else
                    echo "$content"
                fi
                ;;
            done)
                success=$(echo "$line" | jq -r '.success')
                if [[ "$success" == "true" ]]; then
                    echo -e "${GREEN}✓ Done${NC}"
                else
                    echo -e "${RED}✗ Agent failed${NC}"
                fi
                ;;
            *)
                # Unknown type or error - might be regular JSON error response
                if echo "$line" | jq -e '.error' >/dev/null 2>&1; then
                    echo "$line" | jq -r '.error'
                    echo -e "${RED}✗ Request failed${NC}"
                fi
                ;;
        esac
    done
    exit 0
fi

# Non-streaming: make standard request
response=$(make_request_json "POST" "/api/agent" "$json_data")

# Helper to render markdown via glow if available
render_markdown() {
    if command -v glow >/dev/null 2>&1; then
        glow -
    else
        cat
    fi
}

# Handle output based on flags
if [[ "${args[--raw]}" ]]; then
    # Full JSON response
    echo "$response" | jq '.'
elif [[ "${args[--tools]}" ]]; then
    # Response text + tool calls summary
    echo "$response" | jq -r '.data.response' | render_markdown
    echo
    echo "---"
    echo "Tool calls:"
    echo "$response" | jq -r '.data.toolCalls[] | "  \(.name): \(.input.command // .input | tostring | .[0:60])"'
else
    # Default: just the response text
    echo "$response" | jq -r '.data.response' | render_markdown
fi
