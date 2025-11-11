# Project Commands Documentation

## Overview

The `monk project` commands provide **simplified project management** for rapid tenant creation and workflow automation. These commands hide the complexity of tenant administration while providing full access to Monk API capabilities.

**Key Benefits**:
- **Single-command project setup** - No root access or manual tenant management
- **Automatic context switching** - Immediate access to your new project
- **Optional user creation** - Built-in authentication setup
- **Project metadata** - Description and tags for organization
- **Simplified workflow** - From idea to working project in one command

## Command Structure

```bash
monk project COMMAND [OPTIONS]
```

## Available Commands

### **Project Initialization**

#### **Create New Project**
```bash
monk project init <name> [options]
```

**Basic Usage**:
```bash
# Simple project creation
monk project init "Exercise Tracker"

# With description and tags
monk project init "Dog Vaccinations" \
  --description "Track pet vaccination records" \
  --tags personal,pets,health

# With automatic user creation
monk project init "Property Search" \
  --create-user admin \
  --auto-login \
  --description "Real estate search tool"
```

**Options**:
- `--description <text>` - Optional project description
- `--tags <tags>` - Comma-separated project tags
- `--create-user <username>` - Create initial admin user
- `--auto-login` - Automatically login as created user
- `--host <hostname>` - Database host (default: localhost)

**What It Does**:
1. **Creates tenant** using Monk API's root endpoint
2. **Registers tenant** in local CLI configuration
3. **Switches context** to new project automatically
4. **Creates user** (if requested) with admin privileges
5. **Authenticates** (if `--auto-login` specified)
6. **Stores metadata** for project organization

**Example Output**:
```
ℹ Initializing project 'Exercise Tracker'...
ℹ Creating tenant for project...
✓ Project 'Exercise Tracker' created successfully
ℹ Database: tenant_abc123def456
ℹ Adding tenant to local registry...
ℹ Switching to project context...
✓ Switched to project 'Exercise Tracker'

✓ Project 'Exercise Tracker' is ready!

Next steps:
  monk status                    # Show current context
  monk data list users         # Start working with data
  monk describe create schema    # Create your first schema
```

### **Project Management**

#### **List All Projects**
```bash
monk project list [--include-trashed] [--include-deleted]
```

**Examples**:
```bash
# Active projects only
monk project list

# Include soft-deleted projects
monk project list --include-trashed

# Include all projects (including permanently deleted)
monk project list --include-trashed --include-deleted

# JSON output for automation
monk --json project list
```

**Output Format**:
```
PROJECT                   STATUS     DATABASE             HOST                 CREATED
-----------------------  ---------  ---------------      --------------------  -------------------
Exercise Tracker          active     tenant_abc123        localhost            2025-01-10
Dog Vaccinations         active     tenant_def456        localhost            2025-01-10
Property Search *         active     tenant_ghi789        localhost            2025-01-10

Current project: Property Search (server: local)
Total projects: 3
```

#### **Show Project Details**
```bash
monk project show <name>
```

**Examples**:
```bash
# Human-readable details
monk project show "Exercise Tracker"

# Machine-readable JSON
monk --json project show "Exercise Tracker"
```

**Output Format**:
```
Project: Exercise Tracker
Status: active
Database: tenant_abc123
Host: localhost
Created: 2025-01-10 14:30:00 UTC
Description: Track workout sessions and progress
Tags: fitness,health,personal

✓ This is your current project (server: local)

Quick actions:
  monk data list          # List available schemas
  monk describe select      # Show schema definitions
  monk fs ls /data/         # Browse data
```

#### **Switch to Project**
```bash
monk project use <name>
```

**Examples**:
```bash
monk project use "Dog Vaccinations"
```

**Output**:
```
ℹ Switching to project 'Dog Vaccinations'...
✓ Switched to project 'Dog Vaccinations'

Project: Dog Vaccinations
Database: tenant_def456
Server: local (localhost)

Next steps:
  monk status              # Show current context
  monk auth login <user>   # Authenticate to the project
  monk data list         # List available schemas
  monk fs ls /data/        # Browse project data
```

#### **Delete Project**
```bash
monk project delete <name> [--force] [--permanent]
```

**Safety Features**:
- **Soft delete by default** - Projects go to trash first
- **Confirmation required** - Type 'DELETE' to confirm
- **Permanent deletion** - Optional with `--permanent` flag

**Examples**:
```bash
# Soft delete (moves to trash)
monk project delete "Old Project"

# Skip confirmation
monk project delete "Old Project" --force

# Permanent deletion (cannot be recovered)
monk project delete "Old Project" --permanent

# Permanent deletion without confirmation
monk project delete "Old Project" --permanent --force
```

## Workflow Examples

### **Quick Start Workflow**
```bash
# 1. Initialize CLI (first time only)
monk init

# 2. Add server (first time only)
monk server add local localhost:9001
monk server use local

# 3. Create new project (your new workflow!)
monk project init "My App" --create-user admin --auto-login

# 4. Start working immediately
monk data list
```

### **Multi-Project Workflow**
```bash
# Create multiple projects
monk project init "Exercise Tracker" --tags fitness,health
monk project init "Recipe Manager" --tags cooking,food
monk project init "Budget Planner" --tags finance,personal

# List all projects
monk project list

# Switch between projects
monk project use "Exercise Tracker"
# ... work on exercise data ...

monk project use "Recipe Manager"
# ... work on recipes ...

monk project use "Budget Planner"
# ... work on budget ...
```

### **Development Workflow**
```bash
# Create development project
monk project init "Dev Testing" \
  --description "Development and testing environment" \
  --create-user devuser \
  --auto-login

# Create test schemas
monk describe create users < users.json
monk describe create posts < posts.json

# Add test data
monk data create users < test-users.json
monk data create posts < test-posts.json

# Switch to production project
monk project use "Production App"
```

## Integration with Existing Commands

Project commands integrate seamlessly with existing Monk CLI functionality:

### **Authentication**
```bash
# After project init with --create-user
monk auth status              # Shows current authentication
monk auth login admin         # Manual login if not auto-logged in
```

### **Data Operations**
```bash
monk data list              # List schemas in current project
monk data create users        # Create records in project database
monk fs ls /data/            # Browse project data
```

### **Schema Management**
```bash
monk describe select users    # Show schema definition
monk describe create items    # Create new schema in project
```

### **Filesystem Operations**
```bash
monk fs ls /data/            # Browse project data
monk fs cat /data/users/1.json  # Read specific record
```

## Project Metadata

Projects support rich metadata for organization:

### **Storage Location**
```bash
~/.config/monk/cli/projects.json
```

### **Metadata Structure**
```json
{
  "projects": [
    {
      "name": "Exercise Tracker",
      "description": "Track workout sessions and progress",
      "tags": ["fitness", "health", "personal"],
      "created_at": "2025-01-10T14:30:00.000Z",
      "database": "tenant_abc123def456"
    }
  ]
}
```

### **Benefits**
- **Searchable projects** - Filter by tags and descriptions
- **Project context** - Quick identification of project purpose
- **Organization** - Group related projects with tags
- **Audit trail** - Creation timestamps and database mapping

## Error Handling

Project commands provide clear error messages and guidance:

### **Common Issues**
```bash
# No server selected
monk project init "Test"
# Error: No server selected. Use 'monk server use <name>' first.

# Project already exists
monk project init "Existing Project"
# Error: Tenant 'Existing Project' already exists. Use --force to override.

# Project not found
monk project use "Nonexistent"
# Error: Project 'Nonexistent' not found: Tenant 'Nonexistent' not found.
```

### **Recovery Commands**
```bash
# Restore soft-deleted project
monk root tenant restore "Deleted Project"

# Check project health
monk root tenant health "Project Name"

# Show all projects including deleted
monk project list --include-deleted
```

## Best Practices

### **Project Naming**
- **Descriptive names** - "Exercise Tracker" vs "proj1"
- **Consistent conventions** - Use spaces, hyphens, or underscores consistently
- **Avoid conflicts** - Check existing projects with `monk project list`

### **Tag Organization**
```bash
# Good tag examples
monk project init "Work Tasks" --tags work,productivity,tasks
monk project init "Home Budget" --tags personal,finance,budget
monk project init "Client Portal" --tags work,client,web
```

### **User Management**
```bash
# Development projects - create dev user
monk project init "Dev Testing" --create-user devuser --auto-login

# Production projects - create admin user
monk project init "Production App" --create-user admin

# Personal projects - skip user creation (use existing)
monk project init "Personal Notes"
```

### **Backup and Recovery**
```bash
# Before major changes
monk project show "Important Project" --json > project-backup.json

# Export data before deletion
monk data export users ./backup/

# Soft delete first, then permanent if sure
monk project delete "Old Project"
# ... verify it's safe to delete ...
monk project delete "Old Project" --permanent --force
```

## Migration from Root Commands

### **Old Workflow**
```bash
# Complex multi-step process
monk root tenant create "My Project"
monk tenant add my-project "My Project"
monk tenant use my-project
monk auth login my-project admin
# ... manually create users and schemas ...
```

### **New Workflow**
```bash
# Single command setup
monk project init "My Project" --create-user admin --auto-login
# Ready to work immediately!
```

### **Migration Benefits**
- **90% fewer commands** - From 5+ steps to 1 step
- **No root access required** - Works with standard Monk API setup
- **Automatic context** - No manual tenant switching
- **Built-in user management** - Optional user creation and login
- **Project organization** - Metadata and tagging support

---

**The `monk project` commands transform complex tenant administration into a simple, intuitive workflow that gets you from idea to working application in seconds.**