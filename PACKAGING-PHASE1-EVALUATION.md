# Phase 1 Package Management - Core Mechanics Evaluation

**Author**: Ian Zepp <ian.zepp@protonmail.com>
**Date**: 2025-11-13
**Status**: Technical Evaluation

---

## Overview

This document evaluates the core mechanics and implementation details for **Phase 1: Local Package Installation** of the monk package management system.

**Phase 1 Goal**: Support local filesystem package installation via `monk package install /path/to/package`

---

## 1. Command Structure Integration

### 1.1 Bashly Configuration

Add to `src/bashly.yml`:

```yaml
- name: package
  help: Package management for schemas, users, and data bundles

  commands:
  - name: install
    help: Install package from local directory or archive
    args:
    - name: source
      required: true
      help: Package source (directory path, ZIP file, or URL)
    flags:
    - long: --with-fixtures
      help: Install optional fixture data
    - long: --force
      help: Overwrite existing schemas (dangerous)
    - long: --dry-run
      help: Show what would be installed without making changes
    - long: --merge
      help: Merge schemas instead of replacing (default behavior)
      default: true

  - name: list
    help: List installed packages in current tenant
    flags:
    - long: --all-tenants
      help: Show packages across all tenants

  - name: info
    help: Show package details
    args:
    - name: package
      required: true
      help: Package name or path to inspect
```

### 1.2 Implementation Files

New command files needed:
- `src/commands/package/install.sh` - Main installation orchestrator
- `src/commands/package/list.sh` - List installed packages
- `src/commands/package/info.sh` - Package inspection

---

## 2. Installation Flow - Core Mechanics

### 2.1 High-Level Process

```
┌─────────────────────────────────────────────────────────────┐
│ monk package install /path/to/monk-bot                      │
└──────────────────────┬──────────────────────────────────────┘
                       │
                       ▼
         ┌─────────────────────────┐
         │ 1. Validate Package     │
         │    - Check directory    │
         │    - Parse manifest     │
         │    - Validate schema    │
         └──────────┬──────────────┘
                    │
                    ▼
         ┌─────────────────────────┐
         │ 2. Check Dependencies   │
         │    - monk-api version   │
         │    - Package deps       │
         └──────────┬──────────────┘
                    │
                    ▼
         ┌─────────────────────────┐
         │ 3. Install Schemas      │
         │    - Iterate schemas[]  │
         │    - monk describe create│
         └──────────┬──────────────┘
                    │
                    ▼
         ┌─────────────────────────┐
         │ 4. Create Users         │
         │    - Iterate users[]    │
         │    - monk sudo users create│
         └──────────┬──────────────┘
                    │
                    ▼
         ┌─────────────────────────┐
         │ 5. Import Fixtures      │
         │    - If --with-fixtures │
         │    - monk data import   │
         └──────────┬──────────────┘
                    │
                    ▼
         ┌─────────────────────────┐
         │ 6. Record Installation  │
         │    - Save to packages   │
         │    - Track in tenant    │
         └──────────┬──────────────┘
                    │
                    ▼
                 SUCCESS
```

### 2.2 Detailed Step Analysis

#### Step 1: Validate Package

```bash
# Pseudo-implementation
validate_package() {
    local package_path="$1"

    # Check directory exists
    if [ ! -d "$package_path" ]; then
        print_error "Package directory not found: $package_path"
        exit 1
    fi

    # Check manifest exists
    local manifest="$package_path/monk-package.json"
    if [ ! -f "$manifest" ]; then
        print_error "No monk-package.json found in package"
        exit 1
    fi

    # Validate JSON syntax
    if ! jq . "$manifest" >/dev/null 2>&1; then
        print_error "Invalid JSON in monk-package.json"
        exit 1
    fi

    # Validate required fields
    local name version
    name=$(jq -r '.name // empty' "$manifest")
    version=$(jq -r '.version // empty' "$manifest")

    if [ -z "$name" ] || [ -z "$version" ]; then
        print_error "Package manifest missing required fields: name, version"
        exit 1
    fi

    print_success "Package validated: $name@$version"
}
```

**Complexity**: Low - Uses existing jq patterns from other commands

---

#### Step 2: Check Dependencies

```bash
# Pseudo-implementation
check_dependencies() {
    local manifest="$1"

    # Check monk-api version requirement
    local required_version
    required_version=$(jq -r '.requirements["monk-api"] // empty' "$manifest")

    if [ -n "$required_version" ]; then
        # Get server version from API
        local server_version
        server_version=$(make_request "GET" "/api" | jq -r '.version')

        # Semver comparison (simplified - needs proper implementation)
        if ! semver_satisfies "$server_version" "$required_version"; then
            print_error "monk-api version $server_version does not satisfy $required_version"
            exit 1
        fi
    fi

    # Check package dependencies
    local deps
    deps=$(jq -r '.dependencies // {}' "$manifest")

    if [ "$deps" != "{}" ]; then
        # Check each dependency is installed
        # Query package_installations table
        print_warning "Package dependencies found - not yet implemented"
    fi
}
```

**Complexity**: Medium
- Server version check: Easy (existing API pattern)
- Semver comparison: Needs utility function (can use external tool or simple parser)
- Dependency resolution: Complex - defer to later phase

**Phase 1 Decision**: Check monk-api version only, warn on package dependencies

---

#### Step 3: Install Schemas

```bash
# Pseudo-implementation
install_schemas() {
    local package_path="$1"
    local manifest="$package_path/monk-package.json"
    local merge_mode="${2:-true}"  # Default to merge

    # Get schema list from manifest
    local schemas
    schemas=$(jq -r '.schemas[]' "$manifest")

    # Counter for reporting
    local installed=0
    local skipped=0
    local failed=0

    # Iterate schemas
    while IFS= read -r schema_file; do
        local schema_path="$package_path/$schema_file"
        local schema_name
        schema_name=$(basename "$schema_file" .json)

        print_info "Installing schema: $schema_name"

        # Check if schema already exists
        local exists
        exists=$(make_request "GET" "/api/describe/$schema_name" 2>/dev/null)

        if echo "$exists" | jq -e '.success' >/dev/null 2>&1; then
            # Schema exists - handle merge/skip/overwrite
            if [ "$merge_mode" = "true" ]; then
                print_info "Schema exists - merging changes"
                # Use monk describe update (which merges)
                cat "$schema_path" | monk describe update "$schema_name"
            else
                print_warning "Schema exists - skipping (use --force to overwrite)"
                skipped=$((skipped + 1))
                continue
            fi
        else
            # Create new schema
            cat "$schema_path" | monk describe create "$schema_name"
        fi

        # Check result
        if [ $? -eq 0 ]; then
            installed=$((installed + 1))
        else
            failed=$((failed + 1))
            print_error "Failed to install schema: $schema_name"
        fi

    done <<< "$schemas"

    # Report results
    print_success "Schemas installed: $installed, skipped: $skipped, failed: $failed"

    # Exit if any failures
    if [ $failed -gt 0 ]; then
        return 1
    fi
}
```

**Key Mechanics**:
1. **Reuses existing command**: `monk describe create` (via subprocess or direct call)
2. **Schema merging**: Uses `monk describe update` for existing schemas
3. **Error handling**: Tracks failures, continues processing, reports at end
4. **Idempotency**: Checks existence before creating

**Complexity**: Low - Orchestrates existing commands

**Critical Decision**: How to handle schema conflicts?
- **Default: Merge** - Safe upgrades, preserves data
- **--force: Replace** - Dangerous, requires explicit flag
- **--skip: Ignore** - Conservative, no changes

---

#### Step 4: Create Users

```bash
# Pseudo-implementation
create_users() {
    local package_path="$1"
    local manifest="$package_path/monk-package.json"

    # Get user list from manifest
    local users
    users=$(jq -r '.users[]' "$manifest")

    if [ -z "$users" ]; then
        print_info "No users defined in package"
        return 0
    fi

    local created=0
    local skipped=0

    while IFS= read -r user_file; do
        local user_path="$package_path/$user_file"

        # Read user definition
        local auth name access
        auth=$(jq -r '.auth' "$user_path")
        name=$(jq -r '.name // .auth' "$user_path")
        access=$(jq -r '.access // "full"' "$user_path")

        print_info "Creating user: $auth"

        # Check if user already exists (by auth identifier)
        # This requires querying monk sudo users list
        local existing
        existing=$(monk --json sudo users list | jq -r ".data[] | select(.auth == \"$auth\")")

        if [ -n "$existing" ]; then
            print_warning "User already exists: $auth (skipping)"
            skipped=$((skipped + 1))
            continue
        fi

        # Create user
        monk sudo users create --name "$name" --auth "$auth" --access "$access"

        if [ $? -eq 0 ]; then
            created=$((created + 1))
        else
            print_error "Failed to create user: $auth"
            return 1
        fi

    done <<< "$users"

    print_success "Users created: $created, skipped: $skipped"
}
```

**Key Mechanics**:
1. **Reuses**: `monk sudo users create`
2. **Duplicate detection**: Query existing users first
3. **Idempotency**: Skip existing users
4. **Error handling**: Fail fast on user creation errors

**Complexity**: Medium
- Requires sudo token (user must run `monk auth sudo` first)
- Need to query existing users to detect duplicates

**Critical Question**: What if user exists but has different access level?
- **Phase 1**: Skip existing users (conservative)
- **Future**: Add `--update-users` flag to reconcile

---

#### Step 5: Import Fixtures (Optional)

```bash
# Pseudo-implementation
import_fixtures() {
    local package_path="$1"
    local manifest="$package_path/monk-package.json"
    local with_fixtures="${2:-false}"

    # Check flag
    if [ "$with_fixtures" != "true" ]; then
        print_info "Skipping fixtures (use --with-fixtures to install)"
        return 0
    fi

    # Get fixture list
    local fixtures
    fixtures=$(jq -r '.fixtures[]' "$manifest")

    if [ -z "$fixtures" ]; then
        print_info "No fixtures defined in package"
        return 0
    fi

    local imported=0

    while IFS= read -r fixture_file; do
        local fixture_path="$package_path/$fixture_file"

        # Determine schema from file path (e.g., fixtures/users.json -> users)
        local schema
        schema=$(basename "$fixture_file" .json)

        print_info "Importing fixtures for: $schema"

        # Import data (assumes fixture is an array of records)
        cat "$fixture_path" | monk data create "$schema"

        if [ $? -eq 0 ]; then
            imported=$((imported + 1))
        else
            print_warning "Failed to import fixtures for: $schema"
        fi

    done <<< "$fixtures"

    print_success "Fixtures imported: $imported"
}
```

**Key Mechanics**:
1. **Optional**: Only runs with `--with-fixtures` flag
2. **Reuses**: `monk data create` (bulk insert)
3. **Best effort**: Warns on failure but continues

**Complexity**: Low - Simple orchestration

**Design Note**: Fixtures in PACKAGING.md are arrays. May need to support both:
- Single file per schema: `fixtures/users.json` → array of user records
- Multiple files per schema: `fixtures/users/*.json` → directory import

---

#### Step 6: Record Installation

```bash
# Pseudo-implementation
record_installation() {
    local package_path="$1"
    local manifest="$package_path/monk-package.json"
    local tenant_name="$2"  # From current context

    # Extract package metadata
    local name version description author
    name=$(jq -r '.name' "$manifest")
    version=$(jq -r '.version' "$manifest")
    description=$(jq -r '.description // ""' "$manifest")
    author=$(jq -r '.author // ""' "$manifest")

    # Build installation record
    local install_data
    install_data=$(jq -n \
        --arg name "$name" \
        --arg version "$version" \
        --arg description "$description" \
        --arg author "$author" \
        --arg tenant "$tenant_name" \
        --arg source "local" \
        --arg source_path "$package_path" \
        '{
            package_name: $name,
            package_version: $version,
            description: $description,
            author: $author,
            tenant_name: $tenant,
            source: $source,
            source_path: $source_path,
            installed_at: (now | todate)
        }')

    # Save to package_installations schema
    echo "$install_data" | monk data create package_installations

    print_success "Installation recorded for $name@$version"
}
```

**Key Mechanics**:
1. **Metadata storage**: Uses monk-api's own data tables
2. **Schema requirement**: Needs `package_installations` schema in main `monk` database
3. **Tenant tracking**: Records which tenant has this package

**Complexity**: Low - Standard data insert

**Critical Decision**: Where to store package metadata?
- Option A: Main `monk` database (cross-tenant tracking)
- Option B: Per-tenant (isolated, but can't query "which tenants have package X")

**Recommendation**: Main `monk` database (per PACKAGING.md design)

---

## 3. Database Schema Requirements

### 3.1 Package Tracking Tables

These schemas must be created in the **main `monk` database** (not tenant databases):

```sql
-- Schema: packages (package catalog)
CREATE TABLE packages (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  name TEXT NOT NULL,
  version TEXT NOT NULL,
  description TEXT,
  author TEXT,
  homepage TEXT,
  source TEXT,  -- 'local', 'github', 'registry'
  source_url TEXT,
  manifest JSONB NOT NULL,
  created_at TIMESTAMP NOT NULL DEFAULT NOW(),
  UNIQUE(name, version)
);

-- Schema: package_installations (which tenant has what)
CREATE TABLE package_installations (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id UUID NOT NULL REFERENCES tenants(id),
  package_id UUID NOT NULL REFERENCES packages(id),
  installed_version TEXT NOT NULL,
  install_options JSONB,  -- { "with_fixtures": false, ... }
  installed_at TIMESTAMP NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMP NOT NULL DEFAULT NOW(),
  UNIQUE(tenant_id, package_id)
);
```

### 3.2 monk-api JSON Schema Equivalents

For monk-api (which uses JSON schemas, not SQL DDL), these need to be created as schemas in the `monk` tenant:

**packages.json**:
```json
{
  "title": "packages",
  "type": "object",
  "properties": {
    "name": { "type": "string" },
    "version": { "type": "string" },
    "description": { "type": "string" },
    "author": { "type": "string" },
    "homepage": { "type": "string" },
    "source": { "type": "string", "enum": ["local", "github", "registry"] },
    "source_url": { "type": "string" },
    "manifest": { "type": "object" }
  },
  "required": ["name", "version", "manifest"]
}
```

**package_installations.json**:
```json
{
  "title": "package_installations",
  "type": "object",
  "properties": {
    "tenant_name": { "type": "string" },
    "package_name": { "type": "string" },
    "package_version": { "type": "string" },
    "install_options": { "type": "object" }
  },
  "required": ["tenant_name", "package_name", "package_version"]
}
```

### 3.3 Bootstrap Problem

**Problem**: How to create package tracking schemas when package system doesn't exist yet?

**Solution**: Manual bootstrap in monk-api initialization:
1. Add schemas to monk-api's system schemas (created at startup)
2. OR: Create via monk-cli migration script
3. OR: First `monk package install` auto-creates these schemas if missing

**Recommendation**: Auto-create on first use (easiest, most robust)

---

## 4. Error Handling & Rollback

### 4.1 Atomicity Challenges

**Problem**: monk-cli orchestrates multiple API calls (create schema A, B, C, create user X). If step 3 fails, how to rollback steps 1-2?

**Options**:

#### Option A: No Rollback (Phase 1)
- Let user manually clean up
- Idempotent install means they can retry
- Simple to implement

```bash
# On failure at schema 3/6:
print_error "Installation failed at schema 'bot_todos'"
print_info "Partial installation complete. Retry with 'monk package install' to resume."
exit 1
```

#### Option B: Manual Rollback
- Track installed items in array
- On failure, delete created schemas/users
- More complex, not atomic (could fail during rollback)

```bash
installed_schemas=()

# During installation
installed_schemas+=("$schema_name")

# On failure
rollback() {
    print_warning "Rolling back installation..."
    for schema in "${installed_schemas[@]}"; do
        monk describe delete "$schema"
    done
}
trap rollback ERR
```

#### Option C: Transaction-Based (Future)
- Requires monk-api support for multi-operation transactions
- Not available in Phase 1

**Phase 1 Recommendation**: Option A (no rollback)
- Idempotency handles retry
- Clear error messages guide user
- Avoids complex rollback logic that could itself fail

### 4.2 Validation Gates

Fail early with validation:

```bash
# Pre-flight checks (before making ANY changes)
1. Validate package structure
2. Check all schema files exist and are valid JSON
3. Check all user files exist and are valid JSON
4. Verify monk-api version compatibility
5. Check sudo token is available (if creating users)
6. Confirm tenant is selected

# Only after ALL checks pass: begin installation
```

This minimizes partial installation scenarios.

---

## 5. Reusable Components

### 5.1 What Already Exists (Leverage)

| Component | Exists | Location | Usage |
|-----------|--------|----------|-------|
| JSON validation | ✅ | `jq` calls | Validate manifests |
| Schema creation | ✅ | `monk describe create` | Install schemas |
| Schema update | ✅ | `monk describe update` | Merge schemas |
| User creation | ✅ | `monk sudo users create` | Create package users |
| Data import | ✅ | `monk data create` | Import fixtures |
| API request wrapper | ✅ | `make_request()` in common.sh | All API calls |
| Error printing | ✅ | `print_error()` etc. | Consistent UX |
| Config management | ✅ | `get_base_url()`, tenant context | Current tenant |

### 5.2 What Needs to Be Built

| Component | Complexity | Description |
|-----------|------------|-------------|
| Package validator | Low | Check monk-package.json schema |
| Manifest parser | Low | Extract schemas[], users[], fixtures[] |
| Schema conflict resolver | Medium | Merge/skip/overwrite logic |
| User duplicate detector | Medium | Query + compare existing users |
| Installation recorder | Low | Write to package_installations |
| Semver comparator | Medium | Version checking (can use external tool) |

**Total new code**: ~300-500 lines of bash

---

## 6. Dry-Run Mode

### 6.1 Mechanism

```bash
# Flag handling
dry_run="${args[--dry-run]:-false}"

# Wrap all mutation operations
if [ "$dry_run" = "true" ]; then
    print_info "[DRY RUN] Would create schema: $schema_name"
else
    cat "$schema_path" | monk describe create "$schema_name"
fi
```

### 6.2 Value

- Let users preview changes
- Test package structure without side effects
- Validate manifests

**Implementation Cost**: Low - Add conditional branches

---

## 7. Implementation Phases

### 7.1 Minimal Viable Phase 1

**Goal**: Install monk-bot package successfully

**Scope**:
```bash
monk package install /path/to/monk-bot
```

**Deliverables**:
1. ✅ `monk package install <path>` command
2. ✅ Schema installation (with merge support)
3. ✅ User creation
4. ✅ Installation recording
5. ✅ `monk package list` (show installed packages)

**Deferred**:
- ❌ Fixture installation (can manually import)
- ❌ Dependency resolution (warn only)
- ❌ Package uninstall
- ❌ Package update
- ❌ Archive support (ZIP)

**Effort**: 2-3 days

### 7.2 Full Phase 1

Add deferred items:
- Fixture installation (`--with-fixtures`)
- `monk package info <package>` (inspect manifest)
- `--dry-run` mode
- Better error messages

**Effort**: 4-5 days total

---

## 8. Testing Strategy

### 8.1 Manual Test Cases

**Test 1: Fresh Install**
```bash
monk config tenant use test-tenant
monk package install /path/to/monk-bot
# Verify:
# - 6 schemas created
# - monk-bot user created
# - Installation recorded in package_installations
```

**Test 2: Idempotent Reinstall**
```bash
monk package install /path/to/monk-bot
# Verify:
# - No errors
# - Schemas unchanged
# - User not duplicated
```

**Test 3: Upgrade (v1.0 → v1.2)**
```bash
# Install v1.0 (5 columns in bot_cache)
monk package install /path/to/monk-bot-1.0

# Install v1.2 (7 columns in bot_cache)
monk package install /path/to/monk-bot-1.2

# Verify:
# - Schema updated with 2 new columns
# - Existing data preserved
# - Version updated in package_installations
```

**Test 4: Validation Failures**
```bash
# Missing manifest
monk package install /path/to/invalid-package
# Expect: Error before any changes

# Invalid JSON
monk package install /path/to/broken-manifest
# Expect: Error before any changes

# Missing schema file referenced in manifest
# Expect: Error before any changes
```

### 8.2 Integration Tests

Could add to `spec/` directory (uses `bats` testing framework based on existing `spec/` structure):

```bash
# spec/20-package/01-install.test.sh

@test "monk package install validates manifest" {
  run monk package install ./fixtures/invalid-manifest
  [ "$status" -eq 1 ]
  [[ "$output" == *"Invalid JSON"* ]]
}

@test "monk package install creates schemas" {
  run monk package install ./fixtures/test-package
  [ "$status" -eq 0 ]

  # Verify schema exists
  run monk describe select test_schema
  [ "$status" -eq 0 ]
}
```

---

## 9. Critical Decisions Summary

| Decision Point | Recommendation | Rationale |
|----------------|----------------|-----------|
| **Schema conflicts** | Merge by default | Safe upgrades, preserves data |
| **User conflicts** | Skip existing users | Conservative, avoid access changes |
| **Rollback strategy** | No rollback (Phase 1) | Idempotency handles retry |
| **Metadata storage** | Main `monk` database | Cross-tenant queries, centralized |
| **Fixture installation** | Optional flag | Avoid polluting tenant with sample data |
| **Dependency resolution** | Warn only (Phase 1) | Defer complex logic to later phase |
| **Package validation** | Fail early | Prevent partial installations |

---

## 10. Open Questions for Discussion

1. **Sudo Token Management**: Should `monk package install` auto-request sudo if needed, or require user to run `monk auth sudo` first?

2. **Multi-Tenant Installation**: Should Phase 1 support `--all-tenants` flag, or strictly single tenant?

3. **Package Naming**: Allow package name to differ from directory name? (e.g., `monk package install ./my-fork-of-monk-bot` where manifest says `name: "monk-bot"`)

4. **Version Conflicts**: What if tenant has `monk-bot@1.0` installed and user tries to install `monk-bot@2.0`? Upgrade? Error? Allow both?

5. **Manifest Extensions**: Should monk-package.json support `install.sh` script for custom installation logic?

6. **System Schemas**: Should package system schemas (packages, package_installations) be hidden from `monk describe list` output?

---

## 11. Estimated Complexity

### 11.1 Effort Breakdown

| Task | Lines of Code | Complexity | Time |
|------|---------------|------------|------|
| Bashly config | 50 | Low | 1h |
| Package validator | 100 | Low | 2h |
| Schema installer | 150 | Low | 3h |
| User creator | 100 | Medium | 3h |
| Fixture importer | 50 | Low | 1h |
| Installation recorder | 50 | Low | 1h |
| `monk package list` | 100 | Low | 2h |
| Error handling | 50 | Medium | 2h |
| Documentation | N/A | Low | 2h |
| Testing | N/A | Medium | 4h |

**Total**: ~650 LOC, ~21 hours (3 days)

### 11.2 Risk Assessment

| Risk | Likelihood | Impact | Mitigation |
|------|------------|--------|------------|
| Schema merge breaks data | Low | High | Thorough testing, use monk-api's existing update logic |
| User creation fails mid-install | Medium | Medium | Clear error messages, idempotent retry |
| Package metadata conflicts | Low | Low | UNIQUE constraints in DB schema |
| Incomplete rollback | High | Medium | Don't attempt rollback in Phase 1 |
| Version incompatibility | Medium | High | Validate monk-api version before install |

---

## 12. Next Steps

### 12.1 Prerequisites

Before implementation:
1. ✅ Review this evaluation doc
2. ⬜ Decide on open questions (#10)
3. ⬜ Create package metadata schemas in monk-api
4. ⬜ Create monk-bot repository with monk-package.json

### 12.2 Implementation Order

1. Create package metadata schemas (packages, package_installations)
2. Add bashly config for `monk package` commands
3. Implement `monk package install` (local directory only)
4. Implement `monk package list`
5. Test with monk-bot package
6. Document usage in README
7. Add test cases

### 12.3 Future Enhancements (Post-Phase 1)

- Archive support (ZIP)
- GitHub URL installation
- Package update command
- Package uninstall command
- Dependency resolution
- Semver range support
- Package signing/verification

---

## Conclusion

Phase 1 is **highly feasible** with **low-to-medium complexity**. The core mechanics leverage existing monk-cli commands (describe, data, sudo), requiring primarily orchestration logic.

**Key Success Factors**:
1. Thorough pre-flight validation (fail early)
2. Idempotent operations (safe to retry)
3. Clear error messages (guide user on failures)
4. Minimal new code (~650 LOC)
5. Reuse existing battle-tested commands

**Recommendation**: Proceed with Minimal Viable Phase 1 (2-3 days effort) to validate design with real monk-bot installation. Iterate based on learnings.

---

**Author**: Ian Zepp <ian.zepp@protonmail.com>
**Date**: 2025-11-13
**Status**: Ready for Implementation
