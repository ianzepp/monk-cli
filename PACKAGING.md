# monk Package Management

**Status**: Design Document / Future Feature
**Author**: Ian Zepp <ian.zepp@protonmail.com>
**Created**: 2025-11-13

## Problem Statement

monk-bot installation revealed a broader need: **reusable schema + data bundles** for monk-api tenants.

The bot requires 6 schemas (`bot_conversations`, `bot_cache`, `bot_memory`, `bot_todos`, `bot_jobs`, `bot_contexts`) plus a service user account to be created in each tenant. Manually importing schemas and creating users doesn't scale across multiple tenants or evolving package versions.

**Core insight**: This is fundamentally a **package management problem**, not a bot-specific problem. monk-api needs a general-purpose mechanism for distributing, installing, and managing reusable schema collections + data + users.

## Use Cases

Once package management exists, these become trivial:

### Infrastructure Packages
```bash
# Install bot infrastructure
monk package install monk-bot

# Install audit logging schemas
monk package install monk-audit

# Install workflow engine schemas
monk package install monk-workflows
```

### Industry Templates
```bash
# Pre-configured schemas for specific industries
monk package install legal-firm-template
monk package install construction-template
monk package install healthcare-hipaa-template
```

### Third-Party Integrations
```bash
# Integration packages with vendor schemas
monk package install stripe-integration
monk package install sendgrid-integration
monk package install slack-notifications
```

### Tenant Backup/Restore
```bash
# Export tenant structure
monk package export tenant-a > backup.tar.gz

# Clone to new tenant
monk package install ./backup.tar.gz --tenant tenant-b
```

### Application Templates
```bash
# Full application stacks
monk package install blog-cms
monk package install e-commerce-starter
monk package install project-management-suite
```

## Package Structure

### Directory Layout

```
monk-bot/                       # Package root
├── monk-package.json           # Package manifest (required)
├── README.md                   # Package documentation
│
├── schemas/                    # Schema definitions
│   ├── bot_conversations.json
│   ├── bot_cache.json
│   ├── bot_memory.json
│   ├── bot_todos.json
│   ├── bot_jobs.json
│   └── bot_contexts.json
│
├── fixtures/                   # Optional seed data
│   └── initial_system_prompts.json
│
└── users/                      # Optional user definitions
    └── monk-bot.json           # { "auth": "monk-bot", "access": "full" }
```

### monk-package.json

```json
{
  "name": "monk-bot",
  "version": "2.0.0",
  "description": "AI agent bot infrastructure for monk-api",
  "author": "Ian Zepp <ian.zepp@protonmail.com>",
  "license": "MIT",
  "homepage": "https://github.com/ianzepp/monk-bot",

  "requirements": {
    "monk-api": ">=2.0.0"
  },

  "schemas": [
    "schemas/bot_conversations.json",
    "schemas/bot_cache.json",
    "schemas/bot_memory.json",
    "schemas/bot_todos.json",
    "schemas/bot_jobs.json",
    "schemas/bot_contexts.json"
  ],

  "fixtures": [
    "fixtures/initial_system_prompts.json"
  ],

  "users": [
    "users/monk-bot.json"
  ],

  "install": {
    "createUsers": true,
    "importFixtures": false,
    "mergeSchemas": true,
    "skipExisting": false
  },

  "dependencies": {
    "monk-audit": "^1.0.0"
  }
}
```

### User Definition Format

```json
{
  "auth": "monk-bot",
  "name": "Monk Bot",
  "access": "full",
  "type": "bot"
}
```

## monk CLI Commands

### Installation

```bash
# Install from various sources
monk package install monk-bot                                    # From registry (future)
monk package install https://github.com/ianzepp/monk-bot        # From GitHub repo
monk package install /path/to/monk-bot                          # From local directory
monk package install ./monk-bot-2.0.0.zip                       # From local archive
monk package install monk-bot@2.0.0                             # Specific version (requires registry)

# Install with options
monk package install monk-bot --with-fixtures                    # Include seed data
monk package install monk-bot --force                            # Overwrite existing schemas
```

### Package Management

```bash
# List installed packages (in current tenant)
monk package list
monk package list --all-tenants

# Show package info
monk package info monk-bot
monk package info monk-bot@2.0.0

# Update installed package
monk package update monk-bot
monk package update --all

# Remove package (soft-delete schemas/users)
monk package uninstall monk-bot
monk package uninstall monk-bot --hard-delete
```

### Export/Backup

```bash
# Export tenant as package
monk package export --output my-tenant-backup.zip
monk package export --schemas users,tasks --output partial.zip

# Export specific package
monk package export monk-bot --output monk-bot-customized.zip
```

### Registry (Future)

```bash
# Search registry
monk package search bot
monk package search --tag infrastructure

# Publish package
monk package publish ./monk-bot
monk package publish --registry https://packages.monk.sh

# Configure registries
monk package registry add https://packages.monk.sh
monk package registry list
```

## Package Format

**Decision**: ZIP archive containing text files (JSON schemas, manifests, data).

### Why ZIP?
- Everything in monk-api is text (JSON schemas, JSON data)
- ZIP is universal, well-supported
- Compression for large datasets
- Easy to inspect (unzip, read JSON)
- Cross-platform compatible

### Archive Structure
```
monk-bot-2.0.0.zip
├── monk-package.json
├── README.md
├── schemas/
│   └── *.json
├── fixtures/
│   └── *.json
└── users/
    └── *.json
```

### Alternative Formats Considered
- **tar.gz**: Less universal on Windows, no advantage over ZIP
- **Individual files**: Messy, hard to version, no atomic install
- **Container image**: Overkill, requires Docker, wrong abstraction

## Installation Semantics

### Schema Merging (IMPORTANT)

**Decision**: Packages should **merge schemas** by default to support upgrades.

**Example scenario**:
```
monk-bot v1.0.0: bot_cache has 5 columns
monk-bot v1.2.0: bot_cache adds 2 columns (hit_count, last_accessed)

User installs v1.0.0, uses it, stores data
User upgrades to v1.2.0
```

**Expected behavior**:
1. Detect existing `bot_cache` schema
2. Compare with new schema definition
3. Add missing columns: `hit_count`, `last_accessed`
4. Preserve existing data
5. Log changes: "Added 2 columns to bot_cache"

**Implementation**: Use monk-api's schema migration/evolution capabilities.

### Conflict Resolution

**Options** (configurable via flags):

1. **Merge** (default): Add missing columns, preserve existing
2. **Skip**: Don't modify existing schemas
3. **Overwrite**: Replace schema (requires `--force`, risks data loss)
4. **Interactive**: Prompt user for each conflict

### Idempotency

Package installation should be idempotent:
```bash
monk package install monk-bot  # First time: creates schemas
monk package install monk-bot  # Second time: skips existing (or merges if newer version)
```

## Package Registry & Metadata

### Where to Track Installed Packages

**Decision**: Store package metadata in the main `monk` database (not per-tenant).

**Rationale**:
- `monk` database already tracks tenants
- Package name/version is not sensitive information
- Enables cross-tenant queries: "Which tenants have monk-bot installed?"
- Central point for update checking
- Simplifies multi-tenant package management

### Database Schema

```sql
-- In main 'monk' database
CREATE TABLE packages (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  name TEXT NOT NULL,
  version TEXT NOT NULL,
  description TEXT,
  author TEXT,
  homepage TEXT,
  source TEXT,  -- 'registry', 'github', 'local'
  source_url TEXT,
  manifest JSONB NOT NULL,
  created_at TIMESTAMP NOT NULL DEFAULT NOW(),
  UNIQUE(name, version)
);

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

### Query Examples

```sql
-- Which packages are installed in tenant?
SELECT p.name, pi.installed_version, pi.installed_at
FROM package_installations pi
JOIN packages p ON pi.package_id = p.id
WHERE pi.tenant_id = 'eff7af9a-bbc8-423d-a67b-3108b2ef56e4';

-- Which tenants have monk-bot installed?
SELECT t.name, pi.installed_version
FROM package_installations pi
JOIN tenants t ON pi.tenant_id = t.id
JOIN packages p ON pi.package_id = p.id
WHERE p.name = 'monk-bot';

-- Check for updates
SELECT name, installed_version,
       (SELECT MAX(version) FROM packages p2 WHERE p2.name = p.name) as latest_version
FROM package_installations pi
JOIN packages p ON pi.package_id = p.id
WHERE pi.tenant_id = 'current-tenant-id';
```

## Implementation Phases

### Phase 1: Local Packages Only (MVP)

**Goal**: Support local filesystem package installation.

```bash
monk package install /path/to/monk-bot
```

**Implementation**:
1. Read `monk-package.json` from directory
2. Validate manifest schema
3. Import schemas using existing `monk describe create` logic
4. Import fixtures using existing `monk data insert` logic
5. Create users using existing `monk user create` logic
6. Record installation in `package_installations` table
7. Report success/failures

**Minimal new code**: Package parser + orchestration of existing commands.

**Deliverables**:
- `monk package install <path>` command
- `monk package list` command
- `packages` and `package_installations` tables in `monk` database
- monk-bot ships with `monk-package.json`

### Phase 2: Archive Support

**Goal**: Install from ZIP archives.

```bash
monk package install ./monk-bot-2.0.0.zip
```

**Implementation**:
1. Extract ZIP to temp directory
2. Call Phase 1 logic on extracted directory
3. Clean up temp directory

**Addition**: ZIP extraction + temp file management.

### Phase 3: GitHub Support

**Goal**: Install directly from GitHub repos.

```bash
monk package install https://github.com/ianzepp/monk-bot
monk package install github:ianzepp/monk-bot
```

**Implementation**:
1. Detect GitHub URL patterns
2. Download repo archive (releases or main branch)
3. Extract to temp directory
4. Call Phase 1 logic
5. Cache downloads in `~/.monk/packages/cache/`

**Addition**: GitHub API integration + caching.

### Phase 4: Version Management

**Goal**: Support version constraints and updates.

```bash
monk package install monk-bot@2.0.0
monk package update monk-bot
monk package update --all
```

**Implementation**:
1. Parse semver versions
2. Check `package_installations` for current version
3. Compare with available versions
4. Perform schema migrations (merge mode)
5. Update `package_installations` table

**Addition**: Semver parsing + migration logic.

### Phase 5: Package Registry (Future)

**Goal**: Central package discovery and distribution.

```bash
monk package install monk-bot
monk package search infrastructure
monk package publish ./my-package
```

**Implementation**:
1. Package registry API server
2. Package index and search
3. Authentication for publishing
4. Private package support
5. Usage analytics

**Addition**: Full registry infrastructure (separate project).

## Relationship to Existing monk Commands

### monk describe vs monk data vs monk package

**Current state** (confusing separation):
```bash
monk describe create users < schema.json      # Create schema
monk data insert users < data.json            # Insert data
```

**With packages** (unified):
```bash
monk package install my-package               # Creates schemas + inserts data atomically
```

### monk bulk operations

Packages could support bulk operations in manifest:
```json
{
  "bulk": [
    {
      "schema": "users",
      "operation": "update",
      "filter": { "status": "inactive" },
      "set": { "archived": true }
    }
  ]
}
```

Then `monk package install` executes bulk operations as part of setup.

### Data import/export unification

**Before** (manual, error-prone):
```bash
# Export
monk describe get users > users-schema.json
monk data select users --json > users-data.json

# Import
monk describe create users < users-schema.json
monk data insert users < users-data.json
```

**After** (automated, atomic):
```bash
# Export
monk package export --schemas users --output users-package.zip

# Import
monk package install ./users-package.zip
```

## monk-bot Package

### Repository Structure

monk-bot repository will include:

```
monk-bot/
├── monk-package.json           # Package manifest
├── schemas/                    # Bot schemas (already exist)
│   ├── bot_conversations.json
│   ├── bot_cache.json
│   └── ...
├── users/                      # NEW
│   └── monk-bot.json           # Bot user definition
├── fixtures/                   # OPTIONAL
│   └── example_prompts.json
├── src/                        # Bot implementation
├── README.md
├── PLAN.md
└── PACKAGING.md               # This file
```

### Installation (Once Package Management Exists)

**User perspective**:
```bash
# Select tenant
monk config tenant use cli-test

# Install bot package
monk package install monk-bot

# Output:
# ✓ Installed 6 schemas
# ✓ Created user: monk-bot (access: full)
# ✓ Package monk-bot@2.0.0 installed successfully
```

**Bot configuration** (.env):
```bash
TENANT_NAME=cli-test
BOT_USERNAME=monk-bot
# ... rest of config
```

Clean, simple, reusable pattern.

### GitHub Releases

When releasing new monk-bot versions:
```bash
# Create release with packaged archive
zip -r monk-bot-2.0.0.zip monk-package.json schemas/ users/ README.md

# Attach to GitHub release
gh release create v2.0.0 monk-bot-2.0.0.zip
```

Users can then install specific versions:
```bash
monk package install https://github.com/ianzepp/monk-bot/releases/tag/v2.0.0
```

## Design Decisions Summary

| Question | Decision | Rationale |
|----------|----------|-----------|
| Package format | ZIP archive | Universal, compresses JSON, easy to inspect |
| Schema conflicts | Merge by default | Support v1 → v1.2 upgrades without data loss |
| Metadata storage | `monk` database | Central tracking, not sensitive, enables cross-tenant queries |
| File bundling | No schemas in monk-cli | monk-cli stays lightweight, packages are self-contained |
| Installation semantics | Idempotent | Safe to re-run, skips existing or merges updates |
| Version management | Semver | Standard versioning, dependency resolution |

## Open Questions

1. **Package signing**: Should packages be cryptographically signed?
2. **License compliance**: How to handle package licenses?
3. **Dependency resolution**: How to handle package dependencies (monk-bot depends on monk-audit)?
4. **Rollback**: Should package uninstall preserve data or delete it?
5. **Multi-tenant installation**: `monk package install monk-bot --all-tenants`?
6. **Package templates**: Generate new packages with `monk package init`?

## Success Criteria

Package management is successful when:

1. **monk-bot installation**: Single command installs all bot infrastructure
2. **Tenant cloning**: Can export/import entire tenant configurations
3. **Schema evolution**: Upgrading packages merges schema changes safely
4. **Discovery**: Users can find and install community packages
5. **Integration**: Third-party services can distribute monk-api integrations as packages

## Timeline

- **Now**: Document design (this file)
- **Phase 1**: Implement local package installation (when needed)
- **Phase 2-3**: Add archive + GitHub support (when monk-bot stabilizes)
- **Phase 4**: Version management (when multiple packages exist)
- **Phase 5**: Package registry (when ecosystem grows)

## Related Work

### Inspiration from Other Platforms

- **Heroku**: `heroku addons:create` (provision services)
- **Firebase**: `firebase init` (feature enablement)
- **Supabase**: Migration-based extension management
- **npm/pip/cargo**: Language package managers
- **Kubernetes**: Operators + CRDs (declarative resource bundles)
- **WordPress**: Plugin system (schema + code bundles)

monk packages combine:
- Heroku's addon provisioning model
- Supabase's migration-based schema evolution
- npm's versioning and dependency resolution
- Kubernetes' declarative resource management

## Conclusion

Package management solves monk-bot installation **and** provides a foundation for:
- Third-party integrations
- Industry templates
- Tenant backup/restore
- Schema evolution
- Community ecosystem

This is not a blocker for monk-bot Phase 1, but documenting the design now ensures future compatibility and informs current architectural decisions.

---

**Next Steps**:
1. Ship monk-bot with `monk-package.json` in repository (forward compatibility)
2. Document manual installation process in README
3. Implement Phase 1 when multiple packages emerge
4. Iterate based on real-world usage

**Author**: Ian Zepp <ian.zepp@protonmail.com>
**Date**: 2025-11-13
**Status**: Design Document - Not Implemented
