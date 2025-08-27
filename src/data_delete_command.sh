# Check dependencies
check_dependencies

# Get arguments from bashly
schema="${args[schema]}"
id="${args[id]}"

validate_schema "$schema"

if [ -n "$id" ]; then
    # ID provided - direct delete, no stdin needed
    process_data_operation "delete" "DELETE" "$schema" "$id" "" "true"
elif [ -t 0 ]; then
    # No ID and no stdin (terminal input) - error
    print_error "No ID provided and no JSON data on stdin"
    print_info "Usage: monk data delete $schema <id> OR provide JSON with 'id' field(s) via stdin"
    exit 1
else
    # No ID but have stdin - read and process JSON data
    json_data=$(read_and_validate_json_input "deleting" "$schema")
    process_data_operation "delete" "DELETE" "$schema" "" "$json_data" "true"
fi