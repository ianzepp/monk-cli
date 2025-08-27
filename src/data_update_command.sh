# Check dependencies
check_dependencies

# Get arguments from bashly
schema="${args[schema]}"
id="${args[id]}"

validate_schema "$schema"

# Read and validate JSON input
json_data=$(read_and_validate_json_input "updating" "$schema")

# Process the update operation
process_data_operation "update" "PUT" "$schema" "$id" "$json_data"