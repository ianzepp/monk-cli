# Monk Sync Command - Design Document

This document outlines the design for the `monk sync` command, which synchronizes data between tenants, servers, or local directories.

## Overview

The `monk sync` command provides a comprehensive solution for:
- Synchronizing data between remote tenants (same or different servers)
- Pulling data from remote to local directories
- Pushing data from local directories to remote
- Diffing to show differences before syncing
- Patch-based workflows for auditable changes

## Design Philosophy

**Hybrid Approach**: Combine direct sync with separate diff/patch capability for maximum flexibility.

Key principles:
1. **Familiar Unix Patterns**: `pull`/`push`/`copy` mirrors git, rsync, docker
2. **Safe by Default**: Always show diff before destructive operations (unless forced)
3. **Flexible**: Handles remote→local, local→remote, remote→remote
4. **Efficient**: Direct streaming for remote→remote avoids local disk I/O
5. **Composable**: Works with existing `data export/import` for backwards compatibility
6. **Auditable**: Patch files provide change history and review capability

## Command Structure

```yaml
- name: sync
  help: Synchronize data between tenants, servers, or local directories
  
  commands:
  - name: diff
    help: Show differences between two endpoints
    args:
    - name: source
      required: true
      help: "Source endpoint (server:tenant:schema, tenant:schema, or directory)"
    - name: destination
      required: true
      help: "Destination endpoint (server:tenant:schema, tenant:schema, or directory)"
    flags:
    - long: --schema
      short: -s
      arg: schema
      repeatable: true
      help: Specific schema(s) to compare
    - long: --format
      arg: format
      allowed: [summary, detailed, json, unified, side-by-side]
      default: summary
      help: Diff output format
    - long: --output
      short: -o
      arg: file
      help: Save diff to file (creates a patch)
    - long: --filter
      short: -f
      arg: json
      help: Filter DSL to limit comparison scope
    - long: --fields
      arg: fields
      help: "Comma-separated fields to compare (default: all)"
    - long: --ignore-fields
      arg: fields
      help: "Comma-separated fields to ignore (e.g., updated_at,modified_by)"
      
  - name: patch
    help: Apply a previously generated diff/patch
    args:
    - name: patch_file
      required: true
      help: Patch file from sync diff --output
    - name: destination
      required: true
      help: "Destination endpoint to apply patch"
    flags:
    - long: --dry-run
      help: Show what would be changed without applying
    - long: --reverse
      short: -R
      help: Apply patch in reverse (undo)
    - long: --force
      short: -f
      help: Force apply even if conflicts detected
    - long: --strategy
      arg: strategy
      allowed: [theirs, ours, manual]
      default: manual
      help: Conflict resolution strategy
      
  - name: pull
    help: Pull data from remote to local directory
    args:
    - name: source
      required: true
      help: "Source (server:tenant:schema or tenant:schema)"
    - name: directory
      required: true
      help: Local directory path
    flags:
    - long: --schema
      short: -s
      arg: schema
      repeatable: true
      help: Specific schema(s) to sync (default: all)
    - long: --filter
      short: -f
      arg: json
      help: Filter DSL for selective sync
    - long: --overwrite
      help: Overwrite existing files
    - long: --diff-first
      help: Show diff before pulling
      
  - name: push
    help: Push data from local directory to remote
    args:
    - name: directory
      required: true
      help: Local directory path
    - name: destination
      required: true
      help: "Destination (server:tenant:schema or tenant:schema)"
    flags:
    - long: --schema
      short: -s
      arg: schema
      repeatable: true
      help: Specific schema(s) to sync (default: all)
    - long: --merge
      help: Merge with existing data (default: replace)
    - long: --dry-run
      help: Show what would be synced without making changes
    - long: --diff-first
      help: Show diff before pushing
      
  - name: copy
    help: Direct copy between two remotes (streaming, no local storage)
    args:
    - name: source
      required: true
      help: "Source (server:tenant:schema or tenant:schema)"
    - name: destination
      required: true
      help: "Destination (server:tenant:schema or tenant:schema)"
    flags:
    - long: --schema
      short: -s
      arg: schema
      repeatable: true
      help: Specific schema(s) to sync (default: all)
    - long: --filter
      short: -f
      arg: json
      help: Filter DSL for selective sync
    - long: --dry-run
      help: Show what would be synced
    - long: --diff-first
      help: Show differences before syncing
    - long: --strategy
      arg: strategy
      allowed: [replace, merge, skip-existing]
      default: replace
      help: Conflict resolution strategy
```

## Endpoint Format

Unified source/destination format:
```
[server:]tenant:schema
```

Examples:
- `tenant-a:users` - Current server
- `server1:tenant-a:users` - Specific server
- `./backup/users/` - Local directory
- `tenant-a:*` - All schemas (future feature)

## Usage Examples

### Basic Diff
```bash
# Show summary of differences
monk sync diff tenant-a:users tenant-b:users

# Detailed view
monk sync diff tenant-a:users tenant-b:users --format detailed

# Save diff as patch
monk sync diff tenant-a:users tenant-b:users --output changes.patch

# JSON format for scripting
monk sync diff tenant-a:users tenant-b:users --format json > diff.json
```

### Pull (Remote → Local)
```bash
# Pull single schema
monk sync pull tenant-a:users ./backup/users/

# Pull with filter (only active users)
monk sync pull tenant-a:users ./backup/ \
  --filter '{"where": {"status": "active"}}'

# Review changes first
monk sync pull tenant-a:users ./backup/ --diff-first
```

### Push (Local → Remote)
```bash
# Push from local directory
monk sync push ./backup/users/ tenant-b:users

# Merge instead of replace
monk sync push ./backup/users/ tenant-b:users --merge

# Dry run to see what would happen
monk sync push ./backup/users/ tenant-b:users --dry-run
```

### Copy (Remote → Remote)
```bash
# Direct copy between tenants
monk sync copy tenant-a:users tenant-b:users

# Cross-server copy
monk sync copy server1:tenant-a:users server2:tenant-b:users

# With filter (selective copy)
monk sync copy tenant-a:users tenant-b:users \
  --filter '{"where": {"status": "active"}}'

# Show diff before copying
monk sync copy tenant-a:users tenant-b:users --diff-first

# Different strategies
monk sync copy tenant-a:users tenant-b:users --strategy merge
monk sync copy tenant-a:users tenant-b:users --strategy skip-existing
```

### Patch Operations
```bash
# Create patch
monk sync diff prod:users staging:users --output prod-to-staging.patch

# Review patch
cat prod-to-staging.patch | jq '.summary'

# Dry run
monk sync patch prod-to-staging.patch staging:users --dry-run

# Apply patch
monk sync patch prod-to-staging.patch staging:users

# Reverse patch (undo)
monk sync patch prod-to-staging.patch staging:users --reverse
```

## Diff Output Formats

### Summary Format (Default)
```
Summary: tenant-a:users → tenant-b:users
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
Source records:      1,523
Destination records: 1,450
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
Changes:
  ✓ Unchanged:       1,200 records (78.8%)
  + To insert:         300 records (19.7%)
  ~ To update:          23 records (1.5%)
  - To delete:          73 records (in dest, not in source)
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
Estimated sync time: ~2.3s
Estimated data size: 456 KB
```

### Detailed Format
```
INSERT (300 records):
  + user-1001: john.doe@example.com (created: 2024-11-12)
  + user-1002: jane.smith@example.com (created: 2024-11-12)
  ... (show first 10, then "and 290 more")

UPDATE (23 records):
  ~ user-0045: status changed (active → inactive)
  ~ user-0102: email changed (old@example.com → new@example.com)
  ~ user-0234: 3 fields changed (name, email, updated_at)

DELETE (73 records):
  - user-0003: orphaned record (exists in dest but not source)
  - user-0017: orphaned record
  ... (show first 10, then "and 63 more")
```

### JSON Format
```json
{
  "summary": {
    "source": "tenant-a:users",
    "destination": "tenant-b:users",
    "source_count": 1523,
    "destination_count": 1450,
    "unchanged": 1200,
    "to_insert": 300,
    "to_update": 23,
    "to_delete": 73
  },
  "operations": [
    {
      "op": "insert",
      "id": "user-1001",
      "record": {...}
    },
    {
      "op": "update",
      "id": "user-0045",
      "changes": {...}
    }
  ]
}
```

## Patch File Format

```json
{
  "version": "1.0",
  "created_at": "2024-11-12T10:30:00Z",
  "source": {
    "server": "server1",
    "tenant": "tenant-a",
    "schema": "users"
  },
  "destination": {
    "server": "server2",
    "tenant": "tenant-b",
    "schema": "users"
  },
  "metadata": {
    "created_by": "user@example.com",
    "filter": null,
    "ignore_fields": ["updated_at", "modified_by"]
  },
  "checksum": {
    "source": "sha256:abc123...",
    "destination": "sha256:def456..."
  },
  "operations": [
    {
      "op": "insert",
      "id": "user-1001",
      "record": {...}
    },
    {
      "op": "update",
      "id": "user-0045",
      "old": {...},
      "new": {...},
      "patch": {
        "status": "inactive"
      }
    },
    {
      "op": "delete",
      "id": "user-0003",
      "record": {...}
    }
  ]
}
```

## Sync Strategies

### Replace (Default)
Delete all destination records and insert all source records.
```bash
monk sync copy source:users dest:users --strategy replace
```

### Merge
Update existing records by ID, insert new ones. Never delete.
```bash
monk sync copy source:users dest:users --strategy merge
```

### Skip Existing
Only insert records that don't exist in destination.
```bash
monk sync copy source:users dest:users --strategy skip-existing
```

## API Endpoint Considerations

### Should there be an `/api/sync` endpoint?

**Key Question**: What can a server-side sync endpoint offer that the CLI can't do with existing APIs?

#### Scenario Analysis

**Cross-Server Sync** (different servers):
- API endpoint on Server A can't directly access Server B
- Would require Server A to make HTTP requests to Server B (security/firewall issues)
- CLI is better positioned: has credentials for both servers
- **Verdict**: API endpoint doesn't help here

**Same-Server, Cross-Tenant Sync** (tenant-a → tenant-b):
- API endpoint could potentially access both tenants
- But: tenant isolation is a security boundary
- Current auth model: JWT is tenant-scoped
- Would need special cross-tenant permissions
- **Verdict**: Possible but complex security implications

**Same-Tenant Sync** (not useful):
- Syncing within same tenant makes no sense
- **Verdict**: Not applicable

#### What an API Endpoint COULD Offer

**Option 1: Server-Side Diff**
```
POST /api/sync/diff
{
  "source": {
    "schema": "users",
    "filter": {"where": {...}}
  },
  "destination": {
    "schema": "users_backup",  // same tenant
    "filter": {"where": {...}}
  }
}
```
- Only useful for same-tenant schema comparison
- Limited use case (comparing versions of data within tenant)
- CLI can already do this by fetching both datasets

**Option 2: Optimized Bulk Operations**
```
POST /api/sync/apply
{
  "schema": "users",
  "operations": [
    {"op": "insert", "id": "...", "record": {...}},
    {"op": "update", "id": "...", "patch": {...}},
    {"op": "delete", "id": "..."}
  ]
}
```
- Could be more efficient than individual create/update/delete calls
- Transactional: all-or-nothing application
- Better error handling and rollback
- **Verdict**: This is useful!

**Option 3: Webhook-Based Push Sync**
```
POST /api/sync/webhook/register
{
  "schema": "users",
  "target_url": "https://other-server.com/api/sync/receive",
  "events": ["create", "update", "delete"],
  "filter": {"where": {"status": "active"}}
}
```
- Real-time sync via webhooks
- Server A notifies Server B of changes
- Requires both servers to support webhook protocol
- **Verdict**: Interesting but complex, out of scope for v1

**Option 4: Snapshot/Checkpoint API**
```
POST /api/sync/snapshot/:schema
Response: {
  "snapshot_id": "snap_abc123",
  "created_at": "2024-11-12T10:30:00Z",
  "record_count": 1523,
  "checksum": "sha256:..."
}

GET /api/sync/snapshot/:snapshot_id
Response: {
  "records": [...],
  "metadata": {...}
}
```
- Create immutable snapshot for reliable sync
- Prevents data changing mid-sync
- Useful for large datasets
- **Verdict**: Useful for consistency, but can be simulated client-side

#### Recommended API Endpoint Design

**`POST /api/sync/apply`** - Atomic batch operations

This is the most valuable addition:

```json
POST /api/sync/apply/:schema
{
  "operations": [
    {
      "op": "insert",
      "record": {
        "id": "user-1001",
        "email": "john@example.com",
        "status": "active"
      }
    },
    {
      "op": "update",
      "id": "user-0045",
      "patch": {
        "status": "inactive"
      }
    },
    {
      "op": "delete",
      "id": "user-0003"
    }
  ],
  "atomic": true,
  "strategy": "replace|merge|skip-existing",
  "dry_run": false
}

Response:
{
  "success": true,
  "applied": 323,
  "errors": [],
  "results": [
    {"op": "insert", "id": "user-1001", "success": true},
    {"op": "update", "id": "user-0045", "success": true},
    {"op": "delete", "id": "user-0003", "success": true}
  ]
}
```

**Benefits**:
1. **Atomic**: All operations succeed or all fail (with `atomic: true`)
2. **Efficient**: Single HTTP request instead of N requests
3. **Transactional**: Database transaction wrapper
4. **Better Errors**: Detailed error reporting per operation
5. **Dry Run**: Test operations without applying
6. **Strategy Support**: Built-in merge/skip logic

**Existing Bulk API Analysis**

The existing `/api/bulk` endpoint ALREADY supports what we need!

Current capabilities:
- Mixed operations in single transaction: create, update, delete
- Multiple schemas in one request
- Per-operation results
- Synchronous execution with immediate results

Example format:
```json
[
  {
    "operation": "create",
    "schema": "users",
    "data": {"id": "user-1001", "email": "john@example.com"}
  },
  {
    "operation": "update",
    "schema": "users",
    "id": "user-0045",
    "data": {"status": "inactive"}
  },
  {
    "operation": "delete",
    "schema": "users",
    "id": "user-0003"
  }
]
```

**Conclusion**: We can use the existing `/api/bulk` endpoint for efficient patch application!

#### Final Recommendation

**No new API endpoint needed!**

Use existing APIs:
1. **`/api/find/:schema`** - Fetch records with filtering
2. **`/api/data/:schema`** - Individual CRUD operations
3. **`/api/bulk`** - Batch operations for efficient patch application

The CLI will:
- Orchestrate sync logic (fetch from source, compare, apply to dest)
- Use `/api/bulk` for efficient patch application
- Handle cross-server and cross-tenant scenarios
- Manage local file sync

Future enhancements (separate from sync):
- Webhooks for real-time change notifications
- Snapshot API for point-in-time consistency
- Server-side scheduled sync jobs

### Why CLI-First Approach Works

1. **Credentials**: CLI has creds for multiple servers/tenants
2. **Flexibility**: Can work with any combination of endpoints
3. **Local Files**: Can sync to/from filesystem
4. **Filtering**: Can apply filters and transformations client-side
5. **Security**: No need to expose cross-tenant access server-side
6. **Simplicity**: No server-side changes required for v1

### When Server-Side Sync Makes Sense

Future scenarios where server-side sync would be valuable:

1. **Scheduled Background Sync**
   - Server A pulls from Server B on schedule
   - Requires server-side cron/scheduler
   
2. **Event-Driven Sync**
   - Changes in tenant A automatically sync to tenant B
   - Requires webhook/event system
   
3. **Large Dataset Optimization**
   - Server-to-server streaming for TB-scale data
   - Avoids CLI as bottleneck
   
4. **Multi-Tenant SaaS Features**
   - Tenant replication for HA/DR
   - Data sharing between related tenants

For v1, these are out of scope. CLI orchestration is sufficient.

## Implementation Architecture

### File Structure
```
src/commands/sync/
├── diff.sh          # Compare two endpoints
├── patch.sh         # Apply patch file
├── pull.sh          # Remote → Local
├── push.sh          # Local → Remote
└── copy.sh          # Remote → Remote
```

### Helper Functions (in common.sh)
```bash
# Parse endpoint: [server:]tenant:schema or directory path
parse_sync_endpoint() {
    local endpoint="$1"
    # Returns: type, server, tenant, schema, path
}

# Fetch data from remote endpoint
sync_fetch_remote() {
    local server="$1"
    local tenant="$2"
    local schema="$3"
    local filter="$4"
}

# Write data to remote endpoint
sync_write_remote() {
    local server="$1"
    local tenant="$2"
    local schema="$3"
    local data="$4"
    local strategy="$5"
}

# Compute diff between two datasets
sync_compute_diff() {
    local source_data="$1"
    local dest_data="$2"
    local ignore_fields="$3"
}

# Format diff output
sync_format_diff() {
    local diff_json="$1"
    local format="$2"  # summary, detailed, json, unified
}
```

## Real-World Workflows

### Production → Staging Sync
```bash
# Review changes first
monk sync diff prod:users staging:users --format detailed

# Create patch for review
monk sync diff prod:users staging:users --output prod-to-staging.patch

# Apply to staging
monk sync patch prod-to-staging.patch staging:users
```

### Backup Workflow
```bash
# Create backup
monk sync pull prod:users ./backup/users-$(date +%Y%m%d)/

# Later: verify backup integrity
monk sync diff prod:users ./backup/users-20241112/
# Should show: 0 differences (if backup is current)
```

### Migration Testing
```bash
# Create migration patch
monk sync diff old-system:customers new-system:users --output migration.patch

# Test on staging first
monk sync patch migration.patch staging:users --dry-run
monk sync patch migration.patch staging:users

# Verify
monk sync diff old-system:customers staging:users

# Apply to production
monk sync patch migration.patch prod:users
```

### Cross-Server Replication
```bash
# One-time sync
monk sync copy server1:tenant-a:users server2:tenant-b:users

# Incremental sync (only new/modified)
monk sync copy server1:tenant-a:users server2:tenant-b:users \
  --filter '{"where": {"updated_at": {"$gte": "2024-11-12T10:00:00Z"}}}'
```

## Advanced Features (Future)

### Multi-Schema Sync
```bash
# Sync all schemas
monk sync copy tenant-a:* tenant-b:*

# Sync multiple specific schemas
monk sync copy tenant-a:users,orders,products tenant-b:users,orders,products
```

### Schema Sync
```bash
# Include schema definitions
monk sync copy tenant-a:users tenant-b:users --include-schemas

# Schema-only sync (no data)
monk sync copy tenant-a:users tenant-b:users --schemas-only
```

### Conflict Detection
```bash
# Detect conflicts (records modified in both source and dest)
monk sync diff tenant-a:users tenant-b:users --detect-conflicts

# Interactive resolution
monk sync copy tenant-a:users tenant-b:users --strategy interactive
```

### Smart Field Handling
```bash
# Ignore timestamp fields automatically
monk sync diff tenant-a:users tenant-b:users --ignore-timestamps

# Ignore system fields
monk sync diff tenant-a:users tenant-b:users --ignore-system-fields

# Compare specific fields only
monk sync diff tenant-a:users tenant-b:users --fields id,email,status
```

### Incremental Sync
```bash
# Track last sync time automatically
monk sync copy tenant-a:users tenant-b:users --incremental

# Equivalent to:
# monk sync copy tenant-a:users tenant-b:users \
#   --filter '{"where": {"updated_at": {"$gte": "LAST_SYNC_TIME"}}}'
```

## Implementation Phases

### Phase 1: Core Commands (MVP)
1. `sync diff` - Summary and JSON formats only
2. `sync pull` - Wrapper around existing `data export`
3. `sync push` - Wrapper around existing `data import`

### Phase 2: Direct Sync
4. `sync copy` - Direct remote-to-remote with replace strategy

### Phase 3: Patch System
5. `sync diff --output` - Generate patch files
6. `sync patch` - Apply patch files

### Phase 4: Advanced Diff
7. Additional diff formats (detailed, unified, side-by-side)
8. Field-level diff and ignore options

### Phase 5: Advanced Strategies
9. Merge and skip-existing strategies
10. Conflict detection and resolution

### Phase 6: Multi-Schema
11. Support for syncing multiple schemas
12. Schema definition sync

## Migration from Existing Commands

Existing commands remain functional:
```bash
# Still works
monk data export users ./backup/
monk data import users ./backup/

# New equivalent
monk sync pull tenant-a:users ./backup/
monk sync push ./backup/ tenant-b:users
```

## Testing Strategy

### Unit Tests
- Endpoint parsing
- Diff computation
- Patch generation/application

### Integration Tests
- Pull/push with local directories
- Copy between test tenants
- Patch round-trip (diff → patch → apply → verify)

### Manual Testing Scenarios
1. Same-server tenant sync
2. Cross-server tenant sync
3. Backup and restore workflow
4. Incremental sync
5. Error handling (network failures, permission errors, etc.)

## Security Considerations

1. **Authentication**: Use existing server/tenant/auth system
2. **Authorization**: Respect ACLs on both source and destination
3. **Sensitive Data**: Warn when syncing between different security contexts
4. **Audit Trail**: Patch files provide change history
5. **Dry-run**: Always available for preview before changes

## Performance Considerations

1. **Streaming**: Use streaming for large datasets (avoid loading all into memory)
2. **Batching**: Batch operations for better API performance
3. **Compression**: Consider compressing patch files for large diffs
4. **Parallel**: Support parallel schema sync (future)
5. **Progress**: Show progress for long-running operations

## Error Handling

1. **Network Failures**: Retry logic with exponential backoff
2. **Partial Failures**: Track which records succeeded/failed
3. **Schema Mismatches**: Warn or error on incompatible schemas
4. **ID Conflicts**: Handle duplicate IDs gracefully
5. **Permission Errors**: Clear error messages with suggested fixes

## Documentation Deliverables

1. `docs/SYNC.md` - Complete API reference
2. `examples/sync-and-backup.md` - Interactive tutorial
3. Command help text (via bashly)
4. Man page (future)

## Success Metrics

1. Zero data loss during sync operations
2. Clear, actionable diff output
3. Intuitive command structure
4. Good performance on large datasets (10k+ records)
5. Comprehensive error messages
