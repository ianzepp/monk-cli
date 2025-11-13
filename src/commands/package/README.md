# Package Management Commands

## Overview

The `monk package` commands provide a complete package management system for distributing and installing schema definitions across tenants. This enables you to:

- Bundle schema definitions into reusable packages
- Share schemas between tenants and servers
- Version control your database schema definitions
- Automate tenant provisioning with pre-defined schemas

## Package Structure

A monk package is defined by a `monk.json` file:

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

  "describe": [
    "describe/bot_conversations.json",
    "describe/bot_cache.json",
    "describe/bot_memory.json"
  ],

  "data": [
    "data/initial_system_prompts.json"
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

## Commands

### `monk package init`

Initialize a new package definition in the current directory.

**Usage:**
```bash
# Create package with directory name
monk package init

# Create package with custom name
monk package init my-package

# Add description
monk package init my-package --description "My custom schema package"
```

**What it creates:**
- `monk.json` - Package manifest file
- Empty structure ready for schema definitions

**Example:**
```bash
mkdir my-schemas
cd my-schemas
monk package init my-app --description "My application schemas"
```

### `monk package describe add`

Add a schema definition from the current tenant to the package.

**Usage:**
```bash
# Add a schema from current tenant
monk package describe add users

# Add schema and overwrite if exists
monk package describe add users --force
```

**What it does:**
1. Fetches schema definition from current tenant via API
2. Creates `describe/` directory if needed
3. Saves schema to `describe/<schema>.json`
4. Updates `monk.json` describe array

**Example workflow:**
```bash
# Authenticate to source tenant
monk auth login my-app admin

# Initialize package
monk package init my-app

# Add schemas from current tenant
monk package describe add users
monk package describe add products
monk package describe add orders

# View package structure
cat monk.json
ls -la describe/
```

### `monk package install`

Install a package to the current tenant.

**Usage:**
```bash
# Install from directory (finds monk.json automatically)
monk package install ./my-package

# Install from specific file
monk package install ./monk.json

# Preview installation without making changes
monk package install . --dry-run

# Force reinstall (overwrite existing schemas)
monk package install . --force
```

**What it does:**
1. Validates package structure and JSON integrity
2. Reads schema definitions from describe array
3. Creates/updates schemas in current tenant
4. Tracks installation statistics (installed, skipped, failed)

**Example workflow:**
```bash
# Create new empty tenant
monk auth register new-tenant

# Install package
monk package install /path/to/my-package

# Verify installation
monk describe list
```

### `monk package verify`

Verify package integrity and dependencies (stub - not yet implemented).

### `monk package uninstall`

Uninstall a package from the current tenant (stub - not yet implemented).

## Complete Workflow Examples

### Example 1: Create Package from Existing Tenant

```bash
# Step 1: Authenticate to source tenant with schemas
monk config server use dev
monk config tenant use monk-bot-state
monk auth login monk-bot-state admin

# Step 2: Create package directory
mkdir -p ~/packages/monk-bot
cd ~/packages/monk-bot

# Step 3: Initialize package
monk package init monk-bot \
  --description "AI agent bot infrastructure"

# Step 4: Add schemas from tenant
monk package describe add bot_conversations
monk package describe add bot_cache
monk package describe add bot_memory
monk package describe add bot_todos
monk package describe add bot_jobs

# Step 5: Review package
cat monk.json
ls -la describe/

# Step 6: Commit to version control
git init
git add .
git commit -m "Initial monk-bot package"
```

### Example 2: Install Package to New Tenant

```bash
# Step 1: Create new empty tenant
monk auth register test-deployment

# Step 2: Verify tenant is empty
monk describe list
# Output: schemas, users (default schemas only)

# Step 3: Install package (dry-run first)
monk package install ~/packages/monk-bot --dry-run

# Step 4: Install package
monk package install ~/packages/monk-bot

# Step 5: Verify installation
monk describe list
# Output: schemas, users, bot_conversations, bot_cache, bot_memory, ...
```

### Example 3: Update Package with New Schemas

```bash
# Step 1: Switch to source tenant
monk config tenant use monk-bot-state
monk auth login monk-bot-state admin

# Step 2: Add new schema to package
cd ~/packages/monk-bot
monk package describe add bot_contexts

# Step 3: Update version in monk.json
# Edit version: "2.0.0" -> "2.1.0"

# Step 4: Test in development tenant
monk auth register test-update
monk package install .

# Step 5: Commit changes
git add .
git commit -m "Add bot_contexts schema v2.1.0"
git tag v2.1.0
```

### Example 4: Reinstall/Update Schemas

```bash
# Install package to existing tenant (skip existing schemas)
monk package install ~/packages/monk-bot
# Output: 3 installed, 5 skipped (already exist)

# Force reinstall all schemas
monk package install ~/packages/monk-bot --force
# Output: 8 installed, 0 skipped
```

## Package Directory Structure

Typical package layout:

```
my-package/
├── monk.json                       # Package manifest
├── describe/                       # Schema definitions
│   ├── users.json
│   ├── products.json
│   └── orders.json
├── data/                          # Data fixtures (optional)
│   ├── admin_users.json
│   └── default_products.json
└── users/                         # User definitions (optional)
    └── admin.json
```

## Integration with Version Control

Packages are designed to work seamlessly with git:

```bash
# Create package repository
mkdir my-schemas
cd my-schemas
git init

# Create package
monk package init my-app

# Add schemas
monk package describe add users
monk package describe add products

# Commit
git add .
git commit -m "Initial schema package"
git tag v1.0.0
git push origin main --tags

# Other developers can clone and install
git clone <repo-url>
cd my-schemas
monk package install .
```

## Use Cases

### 1. Multi-Tenant SaaS Provisioning
Quickly provision new tenants with standardized schema definitions.

### 2. Environment Promotion
Export schemas from development, install to staging/production.

### 3. Schema Version Control
Track schema changes over time with git commits and tags.

### 4. Team Collaboration
Share schema definitions across team members and environments.

### 5. Disaster Recovery
Restore tenant schemas from package backups.

### 6. Microservices
Each microservice maintains its own schema package.

## Field Naming Conventions

The package format uses monk-specific terminology:

- **`describe`** - Schema definitions (aligns with `monk describe` commands)
- **`data`** - Data fixtures (aligns with `monk data` commands)
- **`users`** - User definitions

This naming mirrors the CLI command structure for consistency.

## Status

**Implemented:**
- ✅ `monk package init` - Create package manifest
- ✅ `monk package describe add` - Add schemas to package
- ✅ `monk package install` - Install package to tenant (partial - has known issues)

**In Progress:**
- ⚠️  `monk package install` - Installation hangs on some schemas (debugging needed)

**Not Yet Implemented:**
- ❌ `monk package verify` - Validate package integrity
- ❌ `monk package uninstall` - Remove package from tenant
- ❌ `monk package data add` - Add data fixtures to package
- ❌ Package installation: data import
- ❌ Package installation: user creation
- ❌ Package installation: dependency resolution

## Future Enhancements

Planned features:
- Remote package URLs (install from GitHub, etc.)
- Package registry/marketplace
- Automatic dependency resolution
- Schema migration tools
- Package signing and verification
- Data fixture management
- User provisioning
