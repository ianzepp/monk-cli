# Bulk API Commands

## Overview

The `monk bulk` command executes multiple operations across schemas in a single transaction. All operations are processed sequentially, and the entire transaction commits on success or rolls back on error - ensuring no partial writes are persisted.

## Command Usage

```bash
monk bulk
```

Reads a JSON array of operations from stdin and executes them as a single transaction.

## Input Format

```json
[
  {
    "operation": "create-one",
    "schema": "users",
    "data": {"name": "Alice", "email": "alice@example.com"}
  },
  {
    "operation": "update-one",
    "schema": "users",
    "id": "user-123",
    "data": {"status": "active"}
  }
]
```

### Operation Object Structure

| Field | Required | Type | Description |
|-------|----------|------|-------------|
| `operation` | Yes | string | Operation type (hyphenated, e.g., `create-one`) |
| `schema` | Yes | string | Target schema name |
| `data` | Varies | object/array | Payload for mutations |
| `id` | Varies | string | Record ID for single-record operations |
| `filter` | Varies | object | Filter criteria for `*-any` operations |
| `aggregate` | Varies | object | Aggregation specification |
| `groupBy` | No | string/array | Group by fields for aggregations |
| `message` | No | string | Custom 404 message for `*-404` operations |

## Supported Operations

### Read Helpers

| Operation | Description | Required Fields | Optional Fields |
|-----------|-------------|----------------|-----------------|
| `select` / `select-all` | Return records matching optional filter | `schema` | `filter` |
| `select-one` | Return single record by ID or filter | `schema` | `id`, `filter` |
| `select-404` | Like `select-one` but raises 404 when missing | `schema` | `id`, `filter`, `message` |
| `count` | Return count of records | `schema` | `filter` |
| `aggregate` | Run aggregations with optional grouping | `schema`, `aggregate` | `filter`, `groupBy` |

### Create Operations

| Operation | Description | Required Fields |
|-----------|-------------|----------------|
| `create` / `create-one` | Create single record | `schema`, `data` (object) |
| `create-all` | Create multiple records | `schema`, `data` (array) |

### Update Operations

| Operation | Description | Required Fields |
|-----------|-------------|----------------|
| `update` / `update-one` | Update record by ID | `schema`, `id`, `data` |
| `update-all` | Update explicit records (each with `id`) | `schema`, `data` (array with `id`) |
| `update-any` | Update records matching filter | `schema`, `filter`, `data` |
| `update-404` | Update single record, raise 404 if missing | `schema`, `data` | `id` or `filter`, `message` |

### Delete Operations (Soft Delete)

| Operation | Description | Required Fields |
|-----------|-------------|----------------|
| `delete` / `delete-one` | Soft delete record by ID | `schema`, `id` |
| `delete-all` | Soft delete explicit records | `schema`, `data` (array with `id`) |
| `delete-any` | Soft delete records matching filter | `schema`, `filter` |
| `delete-404` | Soft delete single record, raise 404 if missing | `schema` | `id` or `filter`, `message` |

### Access Control Operations

| Operation | Description | Required Fields |
|-----------|-------------|----------------|
| `access` / `access-one` | Update ACL fields for record | `schema`, `id`, `data` |
| `access-all` | Update ACL fields for specific IDs | `schema`, `data` (array with `id`) |
| `access-any` | Update ACL fields matching filter | `schema`, `filter`, `data` |
| `access-404` | ACL update, raise 404 if missing | `schema`, `data` | `id` or `filter`, `message` |

### Unsupported Operations

- `select-max` - Not implemented (returns empty array)
- `upsert`, `upsert-one`, `upsert-all` - Not implemented (throws 422 error)

## Examples

### Mixed Operations

```bash
echo '[
  {
    "operation": "create-one",
    "schema": "users",
    "data": {"name": "Jane", "email": "jane@example.com"}
  },
  {
    "operation": "update-one",
    "schema": "users",
    "id": "user-123",
    "data": {"status": "active"}
  },
  {
    "operation": "delete-one",
    "schema": "posts",
    "id": "post-456"
  }
]' | monk bulk
```

Response:
```json
[
  {
    "operation": "create-one",
    "schema": "users",
    "result": {"id": "user-789", "name": "Jane", "email": "jane@example.com"}
  },
  {
    "operation": "update-one",
    "schema": "users",
    "result": {"id": "user-123", "status": "active"}
  },
  {
    "operation": "delete-one",
    "schema": "posts",
    "result": {"id": "post-456", "deleted_at": "2024-11-12T10:30:00Z"}
  }
]
```

### Batch Create

```bash
echo '[
  {
    "operation": "create-all",
    "schema": "users",
    "data": [
      {"name": "Alice", "email": "alice@example.com"},
      {"name": "Bob", "email": "bob@example.com"},
      {"name": "Carol", "email": "carol@example.com"}
    ]
  }
]' | monk bulk
```

### Filter-Based Update

```bash
echo '[
  {
    "operation": "update-any",
    "schema": "orders",
    "filter": {"where": {"status": "pending", "total": {"$gte": 1000}}},
    "data": {"priority": "high"}
  }
]' | monk bulk
```

### Aggregation in Bulk

```bash
echo '[
  {
    "operation": "aggregate",
    "schema": "orders",
    "aggregate": {
      "total_revenue": {"$sum": "amount"},
      "order_count": {"$count": "*"}
    },
    "filter": {"where": {"status": "paid"}},
    "groupBy": ["country"]
  }
]' | monk bulk
```

### Cross-Schema Operations

```bash
echo '[
  {
    "operation": "create-one",
    "schema": "projects",
    "data": {"name": "New Project", "owner_id": "user-123"}
  },
  {
    "operation": "create-all",
    "schema": "tasks",
    "data": [
      {"title": "Setup", "project_id": "proj-456"},
      {"title": "Development", "project_id": "proj-456"}
    ]
  },
  {
    "operation": "update-one",
    "schema": "users",
    "id": "user-123",
    "data": {"active_projects_count": {"$increment": 1}}
  }
]' | monk bulk
```

### Access Control Updates

```bash
echo '[
  {
    "operation": "access-one",
    "schema": "documents",
    "id": "doc-123",
    "data": {
      "access_read": ["user-123", "user-456"],
      "access_write": ["user-123"]
    }
  },
  {
    "operation": "access-any",
    "schema": "documents",
    "filter": {"where": {"folder": "shared"}},
    "data": {
      "access_read": ["team-engineering"]
    }
  }
]' | monk bulk
```

### Explicit Record Updates

```bash
echo '[
  {
    "operation": "update-all",
    "schema": "inventory",
    "data": [
      {"id": "product-1", "stock": 100, "reserved": 10},
      {"id": "product-2", "stock": 50, "reserved": 4},
      {"id": "product-3", "stock": 200, "reserved": 25}
    ]
  }
]' | monk bulk
```

### Conditional Deletions

```bash
echo '[
  {
    "operation": "delete-any",
    "schema": "notifications",
    "filter": {"where": {"read": true, "created_at": {"$lt": "2024-01-01"}}}
  },
  {
    "operation": "delete-any",
    "schema": "sessions",
    "filter": {"where": {"expires_at": {"$lt": "2024-11-12T00:00:00Z"}}}
  }
]' | monk bulk
```

## Response Format

Success response (HTTP 200):
```json
[
  {
    "operation": "create-one",
    "schema": "users",
    "result": {"id": "user-123", "name": "Alice"}
  },
  {
    "operation": "update-one",
    "schema": "users",
    "result": {"id": "user-456", "status": "active"}
  }
]
```

Error response (transaction rolled back):
```json
{
  "success": false,
  "error": "OPERATION_MISSING_DATA",
  "message": "Operation requires data field"
}
```

## Transaction Behavior

All operations execute inside a single database transaction:

- **On Success**: Transaction commits, all changes are persisted, results returned
- **On Error**: Transaction rolls back, no changes are persisted, error returned
- **Atomicity**: All operations succeed together or all fail together

This ensures data consistency across multiple schemas and operations.

## Validation Rules

1. **Array validation**:
   - `create-all`, `update-all`, `delete-all`, `access-all` require `data` to be an array
   - `update-all`, `delete-all`, `access-all` require each element to include `id`

2. **Filter validation**:
   - `update-any`, `delete-any`, `access-any` require `filter` object
   - `*-all` operations reject `filter` (use `*-any` for filter-based operations)

3. **Aggregate validation**:
   - `aggregate` requires non-empty `aggregate` object
   - Does not accept `data` field

4. **ID validation**:
   - `*-one` and `*-404` operations require `id` unless `filter` is provided

## Error Codes

| Status | Error Code | Message | Condition |
|--------|------------|---------|-----------|
| 400 | `REQUEST_INVALID_FORMAT` | "Request body must contain an operations array" | Missing/invalid payload |
| 400 | `OPERATION_MISSING_FIELDS` | "Operation missing required fields" | Missing `operation` or `schema` |
| 400 | `OPERATION_MISSING_ID` | "ID required for operation" | `*-one` without `id` |
| 400 | `OPERATION_MISSING_DATA` | "Operation requires data field" | Mutation without payload |
| 400 | `OPERATION_INVALID_DATA` | "Operation requires data to be [object\|array]" | Wrong payload shape |
| 400 | `OPERATION_MISSING_FILTER` | "Operation requires filter to be an object" | `*-any` without filter |
| 400 | `OPERATION_INVALID_FILTER` | "Operation does not support filter" | `*-all` with filter |
| 400 | `OPERATION_MISSING_AGGREGATE` | "Operation requires aggregate" | `aggregate` without spec |
| 422 | `OPERATION_UNSUPPORTED` | "Unsupported operation" | Upsert / select-max |
| 401 | `TOKEN_MISSING` | "Authorization header required" | Missing bearer token |
| 403 | `PERMISSION_DENIED` | "Operation not authorized" | Lacking schema permission |

## Use Cases

### Data Migration

```bash
# Export from source
monk data export old_schema ./migration/

# Transform to bulk operations
jq '[.[] | {operation: "create-one", schema: "new_schema", data: .}]' \
  ./migration/*.json | monk bulk

# Verify
monk data list new_schema | jq 'length'
```

### Batch Processing

```bash
# Generate operations from CSV
python csv-to-bulk-ops.py input.csv | monk bulk

# Process results
monk bulk < operations.json | jq '.[] | select(.error) | .error'
```

### Cleanup Operations

```bash
echo '[
  {
    "operation": "delete-any",
    "schema": "temp_data",
    "filter": {"where": {"created_at": {"$lt": "2024-01-01"}}}
  },
  {
    "operation": "update-any",
    "schema": "users",
    "filter": {"where": {"last_login": {"$lt": "2024-06-01"}}},
    "data": {"status": "inactive"}
  }
]' | monk bulk
```

### Cross-Schema Relationships

```bash
echo '[
  {
    "operation": "create-one",
    "schema": "projects",
    "data": {"name": "Q4 Initiative", "owner_id": "user-123"}
  },
  {
    "operation": "update-one",
    "schema": "users",
    "id": "user-123",
    "data": {"active_projects": {"$increment": 1}}
  }
]' | monk bulk
```

## Performance Considerations

### Batch Size

- Recommended: < 1000 operations per batch
- Very large batches may timeout
- Consider chunking large datasets

### Transaction Duration

- All operations execute in single transaction
- Long-running transactions may lock resources
- Monitor transaction time for large batches

### Memory Usage

- All operations and results load into memory
- Large payloads increase memory pressure
- Monitor response sizes

## Best Practices

1. **Validate Input**: Test operations on small dataset first
2. **Error Handling**: Always check response for errors
3. **Batch Sizing**: Keep operations under 1000 per batch
4. **Atomicity**: Group related operations for consistency
5. **Logging**: Log bulk operations for audit trails
6. **Testing**: Test in development before production

## Comparison with Individual Commands

| Approach | Command | Performance | Transaction | Use Case |
|----------|---------|-------------|-------------|----------|
| Individual | `monk data create` | Slower (N requests) | Per-operation | Single records, interactive |
| Bulk | `monk bulk` | Faster (1 request) | All-or-nothing | Multiple records, batch jobs |

Choose bulk when:
- Processing multiple records simultaneously
- Need transaction consistency across operations
- Performance is critical
- Working across multiple schemas

Choose individual commands when:
- Single record operations
- Interactive data exploration
- Error isolation is important
- Simple CRUD workflows

## See Also

- `monk find` - Advanced search with Filter DSL
- `monk aggregate` - Statistical queries
- `monk data` - Individual CRUD operations
- `monk sync` - Data synchronization
