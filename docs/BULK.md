# Bulk Commands Documentation

## Overview

The `monk bulk` commands provide **batch processing operations** for executing multiple data operations across schemas in single API transactions. These commands enable efficient bulk data manipulation with immediate execution and planned async capabilities.

**Format Note**: Bulk commands work exclusively with **JSON format** for structured batch operations. The `--text` flag is not supported as bulk operations require structured data input/output.

## Command Structure

```bash
monk bulk <operation> [arguments] [flags]
```

## Available Commands

### **Immediate Bulk Operations**

#### **Execute Raw Bulk Operations (Synchronous)**
```bash
monk bulk raw
```

**Input**: Array of operation objects via stdin

**Examples:**

**Mixed Operations:**
```bash
cat << 'EOF' | monk bulk raw
[
  {
    "operation": "create",
    "schema": "users",
    "data": {"name": "Alice", "email": "alice@example.com"}
  },
  {
    "operation": "create", 
    "schema": "users",
    "data": {"name": "Bob", "email": "bob@example.com"}
  },
  {
    "operation": "update",
    "schema": "users", 
    "id": "123",
    "data": {"status": "verified"}
  },
  {
    "operation": "delete",
    "schema": "posts",
    "id": "456"
  }
]
EOF
```

**Response:**
```json
{"success":true,"results":[{"operation":"create","schema":"users","success":true,"data":{"id":"789","name":"Alice","email":"alice@example.com"}},{"operation":"create","schema":"users","success":true,"data":{"id":"790","name":"Bob","email":"bob@example.com"}},{"operation":"update","schema":"users","success":true,"data":{"id":"123","status":"verified"}},{"operation":"delete","schema":"posts","success":true,"deleted_id":"456"}],"summary":{"total":4,"successful":4,"failed":0}}
```

**Cross-Schema Operations:**
```bash
cat << 'EOF' | monk bulk raw
[
  {
    "operation": "create",
    "schema": "users",
    "data": {"name": "Manager", "role": "admin"}
  },
  {
    "operation": "create", 
    "schema": "projects",
    "data": {"name": "New Project", "owner_id": "123"}
  },
  {
    "operation": "create",
    "schema": "tasks", 
    "data": {"title": "Setup project", "project_id": "456"}
  }
]
EOF
```

## Operation Types

### **Supported Operations**

| Operation | Required Fields | Optional Fields | Description |
|-----------|----------------|----------------|-------------|
| **create** | `schema`, `data` | `message` | Create new record |
| **update** | `schema`, `data` | `id`, `filter`, `message` | Update existing record(s) |
| **delete** | `schema` | `id`, `filter`, `message` | Delete record(s) |
| **select** | `schema` | `id`, `filter`, `limit`, `offset` | Retrieve record(s) |

### **Operation Object Structure**
```json
{
  "operation": "create|update|delete|select",
  "schema": "schema_name",
  "data": { /* record data */ },
  "id": "record_id", 
  "filter": { /* filter criteria */ },
  "limit": 100,
  "offset": 0,
  "message": "Custom operation description"
}
```

## Bulk Operation Examples

### **Bulk User Creation**
```bash
cat << 'EOF' | monk bulk raw
[
  {
    "operation": "create",
    "schema": "users",
    "data": {"name": "Alice Smith", "email": "alice@company.com", "department": "Engineering"}
  },
  {
    "operation": "create", 
    "schema": "users",
    "data": {"name": "Bob Jones", "email": "bob@company.com", "department": "Marketing"}
  },
  {
    "operation": "create",
    "schema": "users", 
    "data": {"name": "Carol Davis", "email": "carol@company.com", "department": "Sales"}
  }
]
EOF
```

### **Bulk Status Update**
```bash
cat << 'EOF' | monk bulk raw
[
  {
    "operation": "update",
    "schema": "users",
    "filter": {"department": "Engineering"},
    "data": {"access_level": "developer"}
  },
  {
    "operation": "update", 
    "schema": "users",
    "filter": {"department": "Marketing"},
    "data": {"access_level": "editor"}
  }
]
EOF
```

### **Data Migration**
```bash
cat << 'EOF' | monk bulk raw
[
  {
    "operation": "create",
    "schema": "new_users",
    "data": {"id": "u1", "name": "Alice", "email": "alice@example.com"}
  },
  {
    "operation": "create",
    "schema": "new_users", 
    "data": {"id": "u2", "name": "Bob", "email": "bob@example.com"}
  },
  {
    "operation": "delete",
    "schema": "old_users",
    "filter": {"migrated": true}
  }
]
EOF
```

### **Cleanup Operations**
```bash
cat << 'EOF' | monk bulk raw
[
  {
    "operation": "delete",
    "schema": "temp_data",
    "filter": {"created_at": {"$lt": "2025-08-01"}}
  },
  {
    "operation": "delete",
    "schema": "log_entries", 
    "filter": {"level": "debug", "timestamp": {"$lt": "2025-08-25"}}
  },
  {
    "operation": "update",
    "schema": "users",
    "filter": {"last_login": {"$lt": "2025-07-01"}},
    "data": {"status": "inactive"}
  }
]
EOF
```

## Future Async Operations

*Note: Async operations are planned for future implementation*

#### **Submit Async Bulk Operation**
```bash
monk bulk submit
```

#### **Check Operation Status**  
```bash
monk bulk status <operation_id>
```

#### **Download Operation Results**
```bash
monk bulk result <operation_id>
```

#### **Cancel Pending Operation**
```bash
monk bulk cancel <operation_id>
```

## Error Handling

### **Invalid Operations**
```bash
cat << 'EOF' | monk bulk raw
[{"operation": "invalid", "schema": "users"}]
EOF
```
```json
{"success":false,"error":"Invalid operation type 'invalid'","supported_operations":["create","update","delete","select"]}
```

### **Schema Validation**
```bash
cat << 'EOF' | monk bulk raw  
[{"operation": "create", "schema": "nonexistent", "data": {}}]
EOF
```
```json
{"success":false,"results":[{"operation":"create","schema":"nonexistent","success":false,"error":"Schema 'nonexistent' not found"}],"summary":{"total":1,"successful":0,"failed":1}}
```

### **Partial Failures**
```bash
cat << 'EOF' | monk bulk raw
[
  {"operation": "create", "schema": "users", "data": {"name": "Valid User", "email": "valid@example.com"}},
  {"operation": "create", "schema": "users", "data": {"invalid_field": "value"}},
  {"operation": "create", "schema": "users", "data": {"name": "Another Valid", "email": "valid2@example.com"}}
]
EOF
```
```json
{"success":true,"results":[{"operation":"create","success":true,"data":{"id":"123"}},{"operation":"create","success":false,"error":"Invalid field 'invalid_field'"},{"operation":"create","success":true,"data":{"id":"124"}}],"summary":{"total":3,"successful":2,"failed":1}}
```

## Format Restrictions

Bulk commands **only support JSON format**:

```bash
# ✅ Correct usage
echo '[{"operation": "create", "schema": "users", "data": {...}}]' | monk bulk raw

# ❌ Invalid format flags  
monk --text bulk raw
# Error: The --text option is not supported for bulk operations
# Bulk operations require JSON format for structured batch processing
```

**Rationale**: Bulk operations require **structured arrays** of operation objects that are inherently JSON-formatted for machine processing and API consistency.

## Performance Considerations

### **Batch Size Optimization**
```bash
# Good: Reasonable batch size
cat operations-100.json | monk bulk raw

# Avoid: Very large batches (may timeout)
cat operations-10000.json | monk bulk raw
```

### **Transaction Efficiency**
- All operations in single request execute as **one transaction**
- **Faster** than individual `monk data` commands for multiple records
- **Atomic**: Either all succeed or all rollback on critical failures

### **Memory Usage**
- Large bulk operations load entirely into memory
- Consider chunking very large datasets
- Monitor response sizes for system limits

## Integration Patterns

### **Data Migration Workflow**
```bash
# 1. Export from source
monk data export old_schema ./migration/

# 2. Transform data format  
python transform-data.py ./migration/ > bulk-operations.json

# 3. Bulk import to new schema
cat bulk-operations.json | monk bulk raw

# 4. Verify migration
monk data select new_schema | jq 'length'
```

### **Batch Processing Pipeline**
```bash
#!/bin/bash
# Process daily data updates

# Generate bulk operations
python generate-daily-updates.py > daily-ops.json

# Execute bulk operations
result=$(cat daily-ops.json | monk bulk raw)

# Check for failures
failed=$(echo "$result" | jq '.summary.failed')
if [ "$failed" -gt 0 ]; then
    echo "❌ $failed operations failed"
    echo "$result" | jq '.results[] | select(.success == false)'
    exit 1
fi

echo "✅ All $(echo "$result" | jq '.summary.successful') operations completed"
```

### **Data Synchronization**
```bash
# Sync users between environments
source_users=$(monk data select users)
cat << EOF | monk bulk raw
[
$(echo "$source_users" | jq -r '.[] | {
  "operation": "create",
  "schema": "users_backup", 
  "data": .
}' | jq -s '. | join(",\n")')
]
EOF
```

## Advanced Features

### **Conditional Operations**
```bash
cat << 'EOF' | monk bulk raw
[
  {
    "operation": "update",
    "schema": "users",
    "filter": {"status": "pending", "created_at": {"$lt": "2025-08-25"}},
    "data": {"status": "expired"}
  },
  {
    "operation": "delete",
    "schema": "sessions",
    "filter": {"expires_at": {"$lt": "2025-08-29T00:00:00Z"}}
  }
]
EOF
```

### **Cross-Schema Relationships**
```bash
cat << 'EOF' | monk bulk raw
[
  {
    "operation": "create",
    "schema": "projects",
    "data": {"name": "New Project", "owner_id": "123"}
  },
  {
    "operation": "update",
    "schema": "users",
    "id": "123", 
    "data": {"active_projects": {"$increment": 1}}
  }
]
EOF
```

## Best Practices

1. **Batch Sizing**: Keep operations under 1000 per batch for optimal performance
2. **Error Handling**: Always check summary for failed operations
3. **Atomic Operations**: Group related operations in single batch for consistency
4. **Schema Validation**: Ensure all schemas exist before bulk operations
5. **Testing**: Test bulk operations in development before production use
6. **Monitoring**: Log bulk operation results for audit trails

## Comparison with Individual Commands

| Approach | Use Case | Performance | Transaction Safety |
|----------|----------|-------------|-------------------|
| **Individual** | `echo '{}' \| monk data create users` | Slower (multiple requests) | Per-operation |
| **Bulk** | `echo '[{}, {}]' \| monk bulk raw` | Faster (single request) | All-or-nothing |

**Choose Bulk When:**
- Processing multiple records simultaneously
- Need transaction consistency across operations
- Performance is critical for large datasets
- Working with cross-schema operations

**Choose Individual When:**
- Single record operations
- Interactive data exploration
- Error isolation is important
- Simple CRUD workflows

Bulk commands provide **efficient, transactional batch processing** for high-performance data operations.