#!/bin/bash

# aggregate_command.sh - Aggregation queries with GROUP BY and statistics
#
# This command performs aggregation operations using the Aggregate API with support
# for filtering, grouping, and statistical functions like COUNT, SUM, AVG, MIN, MAX.
#
# Usage Examples:
#   echo '{"aggregate": {"total": {"$count": "*"}}}' | monk aggregate orders
#   echo '{"where": {"status": "paid"}, "aggregate": {"total_revenue": {"$sum": "amount"}}}' | monk aggregate orders
#   echo '{"aggregate": {"orders": {"$count": "*"}, "revenue": {"$sum": "amount"}}, "groupBy": ["country"]}' | monk aggregate orders
#   cat aggregation-query.json | monk aggregate sales
#
# Aggregation Functions:
#   - $count: Count records (use "*" for all records or field name for non-null values)
#   - $sum: Sum numeric values
#   - $avg: Average of numeric values
#   - $min: Minimum value
#   - $max: Maximum value
#   - $distinct: Count distinct values
#
# Query Structure:
#   where: Optional filter conditions (same as find command)
#   aggregate: Required object with named aggregation functions
#   groupBy: Optional array of field names to group results
#
# API Endpoint:
#   POST /api/aggregate/:schema (with JSON payload)

# Check dependencies
check_dependencies

# Get arguments from bashly
schema="${args[schema]}"

validate_schema "$schema"

# Read and validate JSON input
json_data=$(read_and_validate_json_input "aggregating" "$schema")

# Make the aggregate request
response=$(make_request_json "POST" "/api/aggregate/$schema" "$json_data")

# Use standard response handler
handle_response_json "$response" "aggregate"
