#!/bin/bash

# examples_command.sh - Browse and display usage examples from GitHub

# Check dependencies
check_dependencies

init_cli_configs

# Get current CLI version
get_current_version() {
    monk --version | grep -oE '[0-9]+\.[0-9]+\.[0-9]+'
}

# Get examples for current version (local first, then GitHub)
get_examples_for_version() {
    local version=$(get_current_version)

    # First try local examples directory
    if [[ -d "examples" ]]; then
        ls -1 examples/*.md 2>/dev/null | while read -r file; do
            local name=$(basename "$file" .md)
            local url="file://$PWD/$file"
            echo "${name}|${url}"
        done
        return
    fi

    # Fall back to GitHub API
    local tag="v${version}"
    local repo="ianzepp/monk-cli"  # Discovered via git remote

    # GitHub API: Get directory contents for specific tag
    local api_url="https://api.github.com/repos/${repo}/contents/examples?ref=${tag}"

    curl -s "$api_url" | jq -r '.[] | select(.type == "file") | "\(.name)|\(.download_url)"' 2>/dev/null || echo ""
}

# List all available examples
list_examples() {
    local examples=$(get_examples_for_version)

    if [[ -z "$examples" ]]; then
        print_error "No examples found for version $(get_current_version)"
        print_info "This might be an older version without examples"
        return 1
    fi

    echo "Available examples for monk $(get_current_version):"
    echo

    echo "$examples" | while IFS='|' read -r name url; do
        # Extract title from first line of markdown
        local title=$(curl -s "$url" | head -5 | grep '^# ' | sed 's/^# //' | head -1)
        if [[ -z "$title" ]]; then
            title="No title available"
        fi
        echo "  ${name%.md} - $title"
    done

    echo
    echo "Use 'monk examples <name>' to view an example"
}

# Show specific example
show_example() {
    local example_name="$1"
    local version=$(get_current_version)
    local content=""

    # First try local file
    local local_file="examples/${example_name}.md"
    if [[ -f "$local_file" ]]; then
        content=$(cat "$local_file")
    else
        # Fall back to GitHub
        local tag="v${version}"
        local repo="ianzepp/monk-cli"  # Discovered via git remote

        # Direct raw URL for the file
        local raw_url="https://raw.githubusercontent.com/${repo}/${tag}/examples/${example_name}.md"

        content=$(curl -s "$raw_url")

        if [[ -z "$content" ]] || echo "$content" | grep -q "404: Not Found"; then
            print_error "Example '${example_name}' not found for version ${version}"
            print_info "Try 'monk examples list' to see available examples"
            return 1
        fi
    fi

    # Determine output format
    local output_format=$(get_output_format "glow")

    # Display content based on format and TTY
    if [[ "$output_format" == "text" ]]; then
        # Raw markdown output when --text flag is used
        echo "$content"
    elif [ -t 1 ] && command -v glow >/dev/null 2>&1; then
        # Use glow for enhanced formatting when outputting to terminal
        echo "$content" | glow --width=0 --pager -
    else
        # Fallback to raw markdown if not a TTY or glow not installed
        echo "$content"
    fi
}

# Main command logic
if [[ "${args[name]}" == "list" ]] || [[ -z "${args[name]}" ]]; then
    list_examples
else
    show_example "${args[name]}"
fi