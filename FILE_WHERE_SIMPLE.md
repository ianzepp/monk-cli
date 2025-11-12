# File API WHERE Clause Specification (Simple)

**Version:** 1.0-simple
**Date:** 2025-11-12
**Author:** Claude Code (for monk-cli)
**Target:** monk-api File API - Content Filtering Only

---

## Overview

Add content-based filtering to File API's `/api/file/list` endpoint by integrating Find API's WHERE clause functionality. This allows filtering `.json` file entries based on their record content without requiring separate API calls.

### What This Solves

**Current workflow** (inefficient):
1. `POST /api/file/list` → Get all paths in directory
2. For each `.json` path → Extract record ID
3. `POST /api/find/:schema` → Check if record matches criteria
4. Client combines results

**With WHERE clause** (efficient):
1. `POST /api/file/list` with `where` clause → Get only matching paths
2. Done!

---

## API Changes

### Request Format

Add optional `where` field to `file_options` that accepts a Find API WHERE clause:

```json
POST /api/file/list
{
  "path": "/data/users/",
  "file_options": {
    "recursive": true,
    "max_depth": 3,

    "where": {
      // Standard Find API WHERE clause
      "role": "admin",
      "status": {"$in": ["active", "pending"]},
      "created_at": {"$gte": "2024-01-01T00:00:00Z"}
    }
  }
}
```

### Response Format

**No changes.** Returns same structure, just fewer entries (only those matching the WHERE clause).

```json
{
  "success": true,
  "data": {
    "entries": [
      // Only .json files where record matches WHERE clause
      // Directories always included (can't have content filters)
    ],
    "total": 5,
    "has_more": false,
    "file_metadata": { ... }
  }
}
```

---

## Behavior Specification

### 1. WHERE Clause Scope

The `where` clause **only applies to `.json` files** (record files).

**Processing logic:**
```javascript
async function filterEntry(entry, whereClause) {
  // Directories: Always pass (no content to filter)
  if (entry.file_type === 'd') {
    return true;
  }

  // Non-JSON files: Always pass (no record content)
  if (!entry.name.endsWith('.json')) {
    return true;
  }

  // JSON files: Apply WHERE clause
  const recordId = extractRecordId(entry.path);
  const schema = extractSchema(entry.path);
  const record = await getRecordById(schema, recordId);

  if (!record) return false;

  // Use existing Find API filter matcher
  return matchFindFilter(record, whereClause);
}
```

### 2. Filter Syntax

Use **identical syntax to Find API** `/api/find/:schema` WHERE clause.

**All Find API operators supported:**

#### Comparison Operators
```json
{"age": 25}                        // Exact match (implicit $eq)
{"age": {"$eq": 25}}               // Explicit equality
{"age": {"$ne": 25}}               // Not equal
{"age": {"$gt": 18}}               // Greater than
{"age": {"$gte": 18}}              // Greater than or equal
{"age": {"$lt": 65}}               // Less than
{"age": {"$lte": 65}}              // Less than or equal
{"salary": {"$between": [50000, 100000]}}  // Range
```

#### Array Operators
```json
{"status": {"$in": ["active", "pending"]}}     // One of values
{"status": {"$nin": ["deleted", "banned"]}}    // Not one of values
{"tags": {"$any": ["urgent"]}}                 // Array contains value
{"skills": {"$all": ["js", "ts"]}}             // Array contains all
{"permissions": {"$size": {"$gte": 3}}}        // Array length
```

#### Text Operators
```json
{"email": {"$like": "%@company.com"}}          // SQL LIKE
{"name": {"$ilike": "%john%"}}                 // Case-insensitive LIKE
{"phone": {"$regex": "^\\+1"}}                 // Regular expression
```

#### Logical Operators
```json
// AND (implicit)
{
  "role": "admin",
  "status": "active"
}

// AND (explicit)
{
  "$and": [
    {"role": "admin"},
    {"status": "active"}
  ]
}

// OR
{
  "$or": [
    {"role": "admin"},
    {"permissions": {"$any": ["write"]}}
  ]
}

// NOT
{
  "$not": {"status": "deleted"}
}
```

#### Nested Objects
```json
{
  "metadata": {
    "preferences": {
      "theme": "dark"
    }
  }
}
```

**No new syntax.** Just reuse the existing Find API WHERE clause parser and matcher.

---

## Implementation Guide

### Step 1: Add WHERE to Request Schema

```typescript
interface FileListOptions {
  recursive?: boolean;
  max_depth?: number;
  long_format?: boolean;
  show_hidden?: boolean;
  sort_by?: string;
  sort_order?: 'asc' | 'desc';
  where?: Record<string, any>;  // NEW: Find API WHERE clause
}
```

### Step 2: Filter Logic

```javascript
async function listWithContentFilter(path, options) {
  // 1. Traverse filesystem (existing code)
  const entries = await traverseFileSystem(path, options);

  // 2. If no WHERE clause, return as-is
  if (!options.where) {
    return entries;
  }

  // 3. Filter entries
  const filtered = [];

  for (const entry of entries) {
    // Skip non-JSON files and directories (pass through)
    if (entry.file_type === 'd' || !entry.name.endsWith('.json')) {
      filtered.push(entry);
      continue;
    }

    // Apply WHERE filter to .json files
    try {
      const schema = extractSchemaFromPath(entry.path);
      const recordId = extractRecordIdFromPath(entry.path);

      // Load record
      const record = await loadRecord(schema, recordId);
      if (!record) continue;

      // Apply Find API filter (reuse existing code!)
      if (matchFindFilter(record, options.where)) {
        filtered.push(entry);
      }
    } catch (err) {
      // Log error but continue processing
      console.error(`Failed to filter ${entry.path}:`, err);
    }
  }

  return filtered;
}
```

### Step 3: Reuse Find API Logic

**Critical:** Don't reimplement the WHERE clause parser!

```javascript
// Import from Find API
import { matchFindFilter } from '../find/filter-matcher.js';

// Use it directly
if (matchFindFilter(record, options.where)) {
  filtered.push(entry);
}
```

If the Find API filter matcher isn't easily reusable, make it a shared utility.

---

## Examples

### Example 1: Simple Equality

**Request:**
```json
{
  "path": "/data/users/",
  "file_options": {
    "recursive": true,
    "where": {
      "role": "admin"
    }
  }
}
```

**Result:** Only returns `.json` files where `record.role === "admin"`

---

### Example 2: Multiple Conditions

**Request:**
```json
{
  "path": "/data/users/",
  "file_options": {
    "where": {
      "role": "admin",
      "status": "active",
      "department": "engineering"
    }
  }
}
```

**Result:** Only returns files where ALL three conditions match (implicit AND)

---

### Example 3: Complex Query

**Request:**
```json
{
  "path": "/data/orders/",
  "file_options": {
    "recursive": true,
    "where": {
      "$or": [
        {"status": "pending"},
        {
          "$and": [
            {"status": "processing"},
            {"priority": {"$gte": 8}}
          ]
        }
      ],
      "created_at": {"$gte": "2024-01-01T00:00:00Z"}
    }
  }
}
```

**Result:** Complex boolean logic applied to filter records

---

### Example 4: Array Operations

**Request:**
```json
{
  "path": "/data/documents/",
  "file_options": {
    "where": {
      "access_read": {"$any": ["user-123"]},
      "tags": {"$all": ["approved", "published"]},
      "trashed_at": null
    }
  }
}
```

**Result:** Documents user can read, with required tags, not trashed

---

## CLI Usage (Future)

Once implemented, the CLI will provide convenient syntax:

### Simple Equality (key=value)
```bash
# Single condition
monk fs find /data/users/ -where role=admin

# Multiple conditions (ANDed)
monk fs find /data/users/ -where role=admin -where status=active
```

**CLI translates to:**
```json
{
  "where": {
    "role": "admin",
    "status": "active"
  }
}
```

### Complex Queries (JSON)
```bash
# Use JSON for operators
monk fs find /data/users/ -where '{"age":{"$gte":18}}'

# Mix simple and complex
monk fs find /data/users/ -where role=admin -where '{"age":{"$gte":18}}'
```

**CLI translates to:**
```json
{
  "where": {
    "role": "admin",
    "age": {"$gte": 18}
  }
}
```

### Real-World Examples
```bash
# Find all active admins
monk fs find /data/users/ -w role=admin -w status=active

# Find recent orders
monk fs find /data/orders/ -w '{"created_at":{"$gte":"2024-11-01"}}'

# Find user's accessible documents
monk fs find /data/documents/ -w '{"access_read":{"$any":["user-123"]}}'

# Pipe to other commands
monk fs find /data/users/ -w role=admin | xargs -n1 monk fs cat
```

---

## Performance Considerations

### Optimization Strategy

1. **Lazy evaluation**: Only load records when WHERE clause is present
2. **Early filtering**: Apply filesystem traversal limits (`max_depth`) before content filtering
3. **Batch loading**: Consider loading multiple records in parallel
4. **Caching**: Don't reload same record multiple times in one request

### Example Optimized Flow

```javascript
async function optimizedFilter(path, options) {
  const filtered = [];

  for await (const entry of traverseRecursive(path, options)) {
    // Skip non-filterable entries first (cheap)
    if (shouldSkipContentFilter(entry)) {
      filtered.push(entry);
      continue;
    }

    // Load and filter (expensive - do last)
    if (await matchesContentFilter(entry, options.where)) {
      filtered.push(entry);
    }
  }

  return filtered;
}
```

### Performance Notes

- **Record loading is expensive**: Only do it when necessary
- **Start with filesystem limits**: Use `max_depth`, wildcards to narrow search
- **Cache is your friend**: Consider caching loaded records during traversal
- **Parallel loading**: For large directories, load records in batches

### Typical Query Performance

| Query Type | Records Checked | Expected Time |
|------------|-----------------|---------------|
| `/data/users/` (100 users) | 100 | ~50-100ms |
| `/data/users/` with `max_depth: 1` | 1 | ~1-5ms |
| `/data/` recursive (1000 records) | 1000 | ~500ms-1s |
| `/data/users/*admin*/` (10 matches) | 10 | ~10-20ms |

**Best practice**: Combine WHERE with filesystem limits for optimal performance.

```json
// Good: Narrow path + content filter
{
  "path": "/data/users/*admin*/",
  "file_options": {
    "max_depth": 1,
    "where": {"status": "active"}
  }
}

// Avoid: Broad path + content filter only
{
  "path": "/data/",
  "file_options": {
    "recursive": true,
    "where": {"status": "active"}  // Checks thousands of records!
  }
}
```

---

## Error Handling

### Invalid WHERE Clause

**400 Bad Request** if WHERE clause is invalid:

```json
{
  "success": false,
  "error": "INVALID_WHERE_CLAUSE",
  "error_code": "INVALID_WHERE_CLAUSE",
  "message": "Invalid operator $unknown in WHERE clause"
}
```

### Record Load Failure

**Log but continue** if individual record fails to load:

```javascript
try {
  const record = await loadRecord(schema, recordId);
  if (matchFindFilter(record, options.where)) {
    filtered.push(entry);
  }
} catch (err) {
  // Log error but don't fail entire request
  console.error(`Failed to filter ${entry.path}:`, err);
  // Optionally: Include entry with warning flag
}
```

**Rationale:** One bad record shouldn't break entire directory listing.

---

## Backwards Compatibility

### Without WHERE Clause

Behavior is **identical to current implementation**:

```json
{
  "path": "/data/users/",
  "file_options": {
    "recursive": true
  }
}
```

Returns all entries as it does now.

### With WHERE Clause

New behavior only applies when `where` is present:

```json
{
  "path": "/data/users/",
  "file_options": {
    "where": {"role": "admin"}
  }
}
```

Returns filtered entries.

**Zero breaking changes.**

---

## Testing

### Test Case 1: Simple Equality

**Input:**
```json
{
  "path": "/data/users/",
  "file_options": {
    "where": {"role": "admin"}
  }
}
```

**Expected:**
- Returns only `.json` files where `record.role === "admin"`
- Directories in path always included
- Non-JSON files always included

---

### Test Case 2: No Matches

**Input:**
```json
{
  "path": "/data/users/",
  "file_options": {
    "where": {"role": "superadmin"}
  }
}
```

**Expected:**
- Returns empty entries array (or only directories/non-JSON)
- `total: 0`
- No error

---

### Test Case 3: Complex Query

**Input:**
```json
{
  "path": "/data/",
  "file_options": {
    "recursive": true,
    "where": {
      "$or": [
        {"status": "active"},
        {"priority": {"$gte": 5}}
      ]
    }
  }
}
```

**Expected:**
- Traverses all schemas recursively
- Filters each `.json` file by WHERE clause
- Returns only matching records

---

### Test Case 4: Array Operations

**Input:**
```json
{
  "path": "/data/documents/",
  "file_options": {
    "where": {
      "access_read": {"$any": ["user-123"]}
    }
  }
}
```

**Expected:**
- Only documents where `access_read` array contains `"user-123"`

---

### Test Case 5: Nested Objects

**Input:**
```json
{
  "path": "/data/users/",
  "file_options": {
    "where": {
      "metadata.preferences.theme": "dark"
    }
  }
}
```

**Expected:**
- Filters on nested object properties
- Same syntax as Find API

---

## Success Criteria

### Definition of Done

- ✅ `where` field accepted in `file_options`
- ✅ WHERE clause applied to `.json` files only
- ✅ Directories and non-JSON files always included
- ✅ Reuses Find API filter matcher (no duplication)
- ✅ All Find API operators work correctly
- ✅ Errors logged but don't break request
- ✅ Performance acceptable for 100-1000 record directories
- ✅ Backwards compatible (no breaking changes)
- ✅ All test cases pass
- ✅ Documentation updated

---

## Future Enhancements (Out of Scope)

The following are **NOT** part of this spec and should be implemented separately:

### File Metadata Filtering (Phase 2)
- Filter by `file_type` (f/d/l)
- Filter by `file_size` (min/max)
- Filter by `file_modified` (before/after)
- Filter by `file_permissions`

### Performance Optimizations (Phase 3)
- Parallel record loading
- Result streaming
- Query optimization hints
- Caching strategies

These can be added later without breaking changes.

---

## Questions for Implementor

1. **Find API Reuse**: Can we import the WHERE clause matcher from Find API, or does it need to be refactored into a shared utility?

2. **Error Handling**: Should we fail the entire request if one record fails to load, or skip it and continue?

3. **Performance**: What's the typical directory size we should optimize for? 100 records? 1000? 10,000?

4. **Caching**: Should loaded records be cached within a single request to avoid duplicate loads?

5. **Schema Extraction**: Is there a utility to extract schema name from a file path like `/data/users/user-123.json` → `"users"`?

---

## Summary

This spec adds **one simple feature** to File API:

> **Content-based filtering using Find API WHERE syntax**

**Implementation checklist:**
1. Add `where?: Record<string, any>` to `FileListOptions`
2. After filesystem traversal, filter `.json` entries by WHERE clause
3. Reuse existing Find API filter matcher
4. Return filtered entries

**Estimated complexity:** Low-Medium (mostly integration, minimal new code)

**Value:** High (enables efficient `monk fs find` command for 75%+ of use cases)
