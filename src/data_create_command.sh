# Check dependencies
check_dependencies

# Get arguments from bashly
schema="${args[schema]}"

validate_schema "$schema"

# Read and validate JSON input
json_data=$(read_and_validate_json_input "creating" "$schema")

# Process the create operation
process_data_operation "create" "POST" "$schema" "" "$json_data"