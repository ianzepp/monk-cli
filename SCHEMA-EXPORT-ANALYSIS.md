# Schema Export Analysis - Current Capabilities

**Author**: Ian Zepp <ian.zepp@protonmail.com>
**Date**: 2025-11-13

## Question
Is there functionality to export one or many schemas from a tenant, or must we do it one-by-one?

---

## Current Capabilities

### 1. Schema Export (One-by-One)

**Command**: `monk describe select <schema>`
- **Location**: `src/commands/describe/select.sh:38`
- **API**: `GET /api/describe/:name`
- **Output**: JSON schema definition for a single schema
- **Usage**:
  ```bash
  monk describe select users > users-schema.json
  monk describe select products > products-schema.json
  ```

### 2. Schema Listing

**Command**: `monk describe list`
- **Location**: `src/commands/describe/list.sh:28`
- **API**: `GET /api/describe`
- **Output**: Array of schema names (not full definitions)
- **Usage**:
  ```bash
  monk describe list
  # Output:
  # users
  # products
  # orders
  ```

### 3. Data Export (Records, Not Schemas)

**Command**: `monk data export <schema> <dir>`
- **Location**: `src/commands/data/export.sh:44`
- **API**: `GET /api/data/:schema`
- **Output**: Individual JSON files per record (NOT schema definitions)
- **Usage**:
  ```bash
  monk data export users ./backup/users/
  # Creates: ./backup/users/{id}.json for each record
  ```

**Note**: This exports record data, NOT schema definitions.

### 4. Bulk API

**Command**: `monk bulk` (accepts JSON operations array via stdin)
- **Location**: `src/commands/bulk.sh:84`
- **API**: `POST /api/bulk`
- **Supported Operations**:
  - `select`, `select-one`, `select-all` (for data records)
  - `count`, `aggregate`
  - `create`, `update`, `delete`, `access`

**Limitation**: Bulk operations work on **data records**, not schema definitions.

The bulk API has no `describe` operation to fetch schema definitions.

### 5. Meta Schema API (Hidden Gem!)

**API**: `GET /api/meta/schema`
- **Location**: Used in `src/lib/common.sh` for schema validation
- **Returns**: Appears to return information about all schemas
- **Current Usage**: Schema validation only

**Code Reference** (`src/lib/common.sh`):
```bash
if response=$(make_request_json "GET" "/api/meta/schema" "" 2>/dev/null); then
    if echo "$response" | grep -q "\"$schema\""; then
        print_info "Schema validated: $schema"
    fi
fi
```

**Potential**: This endpoint might return all schema definitions in one call!

### 6. File API

**Command**: `monk fs ls /path`, `monk fs cat /path`
- **Paths**: `/data/{schema}/`, `/meta/schema/`, `/tenant/{name}/...`
- **API**: `POST /api/file/list`, `POST /api/file/cat`

**Note**: File API paths like `/meta/schema/` are mentioned in help text, suggesting filesystem-like access to schemas.

---

## Gap Analysis

### Current State
✅ **Can export single schema**: `monk describe select users`
✅ **Can list all schema names**: `monk describe list`
✅ **Possible bulk endpoint exists**: `GET /api/meta/schema` (needs investigation)
❌ **No CLI command for bulk export**: Must loop or use undocumented endpoint
❌ **No bulk describe operation**: Bulk API doesn't support schema operations

### For Package Export, We Need:

**Option A: Loop Over Schemas (Current Approach)**
```bash
# Get all schema names
schemas=$(monk describe list)

# Loop and export each
for schema in $schemas; do
  monk describe select "$schema" > "schemas/$schema.json"
done
```

**Pros**:
- Works with existing commands
- No new API calls needed

**Cons**:
- N+1 API calls (1 list + N selects)
- Slow for tenants with many schemas

---

**Option B: Use Bulk API for Schemas (Requires API Enhancement)**
```bash
# Build bulk operations array
operations=$(monk describe list --json | jq '[.data[] | {
  operation: "describe-select",
  schema: .
}]')

# Execute in single API call
echo "$operations" | monk bulk
```

**Pros**:
- Single API round-trip
- Atomic snapshot of all schemas

**Cons**:
- **Requires monk-api enhancement**: Bulk API doesn't support `describe` operations yet
- Breaking change to bulk API (needs new operation type)

---

**Option C: New Command - `monk describe export-all`**
```bash
monk describe export-all ./schemas/
# Creates: ./schemas/users.json, ./schemas/products.json, etc.
```

**Implementation**:
```bash
#!/bin/bash
# describe_export_all_command.sh

directory="${args[dir]}"

# Get all schema names
schemas=$(monk describe list)

# Export each to directory
mkdir -p "$directory"
count=0

for schema in $schemas; do
  print_info "Exporting schema: $schema"
  monk describe select "$schema" > "$directory/$schema.json"

  if [ $? -eq 0 ]; then
    count=$((count + 1))
  else
    print_error "Failed to export: $schema"
  fi
done

print_success "Exported $count schemas to $directory"
```

**Pros**:
- Clean UX for package export
- No API changes needed
- Mirrors `monk data export` pattern

**Cons**:
- Still N+1 API calls under the hood

---

**Option D: File API - `/meta/schema/`**

**Hypothesis**: If monk-api exposes schemas via File API at `/meta/schema/`, we could:
```bash
monk fs ls /meta/schema/           # List all schemas
monk fs cat /meta/schema/users     # Get schema definition
```

**Investigation Needed**:
- Does `/meta/schema/` exist in monk-api?
- Does it return schema definitions?
- Can we bulk fetch via File API?

**Test**:
```bash
CLI_VERBOSE=true monk fs ls /meta/schema/
```

---

## Recommendations

### For Phase 1 Package Management

**Short-term (Phase 1)**:
Use **Option A** (loop over schemas) inside `monk package export`:

```bash
# monk package export implementation
export_schemas() {
  local package_dir="$1"
  local schemas_dir="$package_dir/schemas"

  mkdir -p "$schemas_dir"

  # Get all schema names
  local schema_list
  schema_list=$(monk describe list)

  # Export each
  for schema in $schema_list; do
    print_info "Exporting schema: $schema"
    monk describe select "$schema" > "$schemas_dir/$schema.json"
  done

  print_success "Exported schemas to $schemas_dir"
}
```

**Rationale**:
- Works with existing API
- Simple, reliable
- N+1 calls acceptable for Phase 1 (most tenants have < 20 schemas)

---

**Medium-term (Phase 2)**:
Add **Option C** (`monk describe export-all`) as dedicated command:

```bash
monk describe export-all ./my-package/schemas/
```

**Benefits**:
- Cleaner UX
- Reusable for non-package workflows
- Matches `monk data export` pattern

---

**Long-term (Phase 3+)**:
Enhance bulk API to support schema operations:

```json
[
  {
    "operation": "describe-select",
    "schema": "users"
  },
  {
    "operation": "describe-select",
    "schema": "products"
  }
]
```

**Benefits**:
- Single API call
- Atomic snapshot
- Consistent with bulk patterns

**Requires**: monk-api enhancement

---

## API Investigation Needed

### Test 1: Meta Schema Bulk Endpoint

**Action**: Test if `GET /api/meta/schema` returns all schema definitions:

```bash
# Direct API test
monk curl GET /api/meta/schema | jq .

# Expected output (hypothesis):
# {
#   "success": true,
#   "data": {
#     "users": { "title": "users", "properties": {...} },
#     "products": { "title": "products", "properties": {...} },
#     ...
#   }
# }
```

**If this returns all schemas**, we can skip N+1 API calls entirely!

### Test 2: File API Schema Access

**Action**: Test if `/meta/schema/` provides filesystem-like access:

```bash
# Test 1: List schemas via File API
CLI_VERBOSE=true monk fs ls /meta/schema/

# Test 2: Cat a schema definition
CLI_VERBOSE=true monk fs cat /meta/schema/users

# Test 3: Check if it returns schema JSON
monk fs cat /meta/schema/users | jq .
```

**If successful**, this could provide:
- Unified filesystem metaphor for schemas
- Potential for wildcard export: `monk fs cp /meta/schema/* ./backup/schemas/`
- Alternative to N+1 API calls

---

## Conclusion

**Answer**: Currently, schema export is **one-by-one** via `monk describe select`.

**For package export**, the recommended approach is:

### Phase 1: Loop Over Schemas
```bash
# In monk package export implementation
for schema in $(monk describe list); do
  monk describe select "$schema" > "schemas/$schema.json"
done
```

### Future: Dedicated Bulk Export
```bash
monk describe export-all ./package/schemas/
```

**Performance**: For typical tenant (10-20 schemas), N+1 API calls are acceptable. For larger tenants (100+ schemas), consider:
1. Parallel exports (background jobs)
2. Bulk API enhancement
3. File API exploration

---

**Next Steps**:
1. ✅ Document current capabilities (this file)
2. ⬜ **PRIORITY**: Test `GET /api/meta/schema` for bulk export
3. ⬜ Test File API `/meta/schema/` path
4. ⬜ Implement `monk package export` (use bulk endpoint if available, else loop)
5. ⬜ Consider adding `monk describe export-all` in future release

---

## Discovery: Hidden Bulk Endpoint?

**Finding**: `src/lib/common.sh` references `GET /api/meta/schema` for schema validation.

**Hypothesis**: This endpoint may return ALL schema definitions in a single call, avoiding N+1 problem.

**Validation Needed**:
```bash
# Test if this returns all schemas
monk curl GET /api/meta/schema --json | jq .
```

**If confirmed**, Phase 1 package export becomes trivial:
```bash
# Single API call to export all schemas
response=$(monk curl GET /api/meta/schema --json)
echo "$response" | jq -r '.data | keys[]' | while read schema; do
  echo "$response" | jq ".data[\"$schema\"]" > "schemas/$schema.json"
done
```

This would be a **significant simplification** over N+1 approach!
