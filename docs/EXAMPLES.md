# Examples Command Documentation

## Overview

The `monk examples` command provides **interactive examples and complete workflows** for learning and exploring Monk CLI capabilities. This command is designed as a **getting started guide** for new users and a reference for experienced users looking for specific patterns.

**Key Benefits**:
- **Interactive browsing** - Explore examples at your own pace
- **Complete workflows** - From setup to working application
- **Real-world scenarios** - Practical examples for common use cases
- **Copy-paste ready** - Commands that work immediately
- **Progressive learning** - From basic to advanced concepts

## Command Structure

```bash
monk examples [name]
```

## Usage Examples

### **List All Available Examples**
```bash
monk examples
```

**Output Example:**
```
Available Examples

1. basic-setup          Basic CLI setup and first project
   Description: Complete setup from scratch to working project
   
2. exercise-tracker     Exercise tracking application
   Description: Build a workout tracking app with users and exercises
   
3. data-crud           Basic data operations
   Description: Learn create, read, update, delete operations
   
4. server-management   Multi-environment server setup
   Description: Configure development, staging, and production servers
   
5. tenant-management   Project and tenant workflows
   Description: Advanced project management and organization
   
6. bulk-operations     Batch data processing
   Description: Efficient bulk operations for large datasets

Usage:
  monk examples <name>           # View specific example
  monk examples                  # Show this list
```

### **View Specific Example**
```bash
monk examples basic-setup
```

**Output Example:**
```
# Basic CLI Setup and First Project

This example walks you through setting up Monk CLI from scratch and creating your first project.

## Prerequisites
- Monk CLI installed
- Monk API server running (or access to remote server)

## Step 1: Initialize CLI Configuration
```bash
# Initialize CLI with default configuration directory
monk init

# Or specify custom directory
monk init ~/.config/monk/custom
```

## Step 2: Add Server Connection
```bash
# Add local development server
monk server add local localhost:9001 --description "Local development server"

# Switch to the server
monk server use local

# Verify server connectivity
monk server ping
```

## Step 3: Create Your First Project
```bash
# Create a new project with automatic user setup
monk project init "My First App" \
  --description "Learning Monk CLI" \
  --create-user admin \
  --auto-login

# Check your current status
monk status
```

## Step 4: Create Your First Schema
```bash
# Create a simple users schema
cat << 'EOF' | monk describe create users
{
  "type": "object",
  "properties": {
    "name": {"type": "string"},
    "email": {"type": "string"},
    "created_at": {"type": "string", "format": "date-time"}
  }
}
EOF
```

## Step 5: Add Some Data
```bash
# Add a user record
cat << 'EOF' | monk data create users
{
  "name": "Alice Johnson",
  "email": "alice@example.com"
}
EOF

# List all users
monk data list users
```

## Step 6: Explore Your Data
```bash
# Browse data using filesystem interface
monk fs ls /data/
monk fs ls /data/users/

# View specific record
monk fs cat /data/users/1.json
```

## What You've Learned
- CLI initialization and configuration
- Server management and connectivity
- Project creation and user management
- Schema definition and data operations
- Filesystem-style data browsing

## Next Steps
Try the "exercise-tracker" example to build a more complete application.
```

## Available Examples

### **1. Basic Setup (`basic-setup`)**
**Target Audience**: New users to Monk CLI

**What You'll Learn**:
- CLI initialization and configuration
- Server connection setup
- Project creation with user management
- Basic schema and data operations
- Filesystem interface usage

**Duration**: 10-15 minutes

**Prerequisites**: None

### **2. Exercise Tracker (`exercise-tracker`)**
**Target Audience**: Users comfortable with basic operations

**What You'll Learn**:
- Multi-schema design (users, workouts, exercises)
- Data relationships and foreign keys
- Advanced querying with filters
- Data export and import
- Project organization best practices

**Duration**: 20-30 minutes

**Prerequisites**: Basic setup completion

### **3. Data CRUD (`data-crud`)**
**Target Audience**: Users needing data manipulation skills

**What You'll Learn**:
- Create, read, update, delete operations
- Batch operations with bulk commands
- Data validation and error handling
- Query optimization techniques
- Data backup and recovery

**Duration**: 15-20 minutes

**Prerequisites**: Basic setup completion

### **4. Server Management (`server-management`)**
**Target Audience**: DevOps and system administrators

**What You'll Learn**:
- Multi-environment setup (dev/staging/prod)
- Server health monitoring
- Configuration management
- Authentication across environments
- Deployment workflows

**Duration**: 25-35 minutes

**Prerequisites**: Access to multiple Monk API servers

### **5. Tenant Management (`tenant-management`)**
**Target Audience**: Project managers and team leads

**What You'll Learn**:
- Project lifecycle management
- Multi-tenant architecture
- User access control
- Project organization with tags
- Backup and migration strategies

**Duration**: 20-30 minutes

**Prerequisites**: Server management experience

### **6. Bulk Operations (`bulk-operations`)**
**Target Audience**: Data engineers and power users

**What You'll Learn**:
- Batch data processing
- Performance optimization
- Large dataset handling
- Error recovery and retry logic
- Monitoring and logging

**Duration**: 30-40 minutes

**Prerequisites**: Data CRUD experience

## Example Structure

Each example follows a consistent structure:

### **Header Information**
- Title and description
- Target audience and duration
- Prerequisites and learning objectives

### **Step-by-Step Instructions**
- Numbered steps with clear commands
- Expected output examples
- Explanations of what each command does

### **Learning Summary**
- Key concepts covered
- Skills acquired
- How they apply to real scenarios

### **Next Steps**
- Recommended follow-up examples
- Advanced topics to explore
- Real-world application ideas

## Interactive Features

### **Progress Tracking**
Examples include checkpoints to verify your progress:

```bash
# Verify your setup at any point
monk status

# Expected output should show:
# - Server: configured and reachable
# - Tenant: selected and accessible
# - Authentication: valid token
# - Schemas: appropriate count for example
```

### **Error Recovery**
Each example includes common error scenarios and solutions:

```bash
# If you get "Not authenticated" error:
monk auth login <tenant> <username>

# If you get "Server not found" error:
monk server use <server-name>

# If you get "Schema not found" error:
monk describe select  # List available schemas
```

### **Customization Points**
Examples show where to customize for your needs:

```bash
# Replace with your project name
monk project init "Your Project Name"

# Replace with your server details
monk server add production your-api.com:443

# Replace with your user preferences
monk project init "My App" --create-user your-username
```

## Learning Path

### **Beginner Path**
1. `basic-setup` → Learn fundamentals
2. `data-crud` → Master data operations
3. `exercise-tracker` → Build complete application

### **Advanced Path**
1. `server-management` → Multi-environment setup
2. `tenant-management` → Project organization
3. `bulk-operations` → Large-scale data processing

### **Role-Based Path**

**Developers**:
- basic-setup → data-crud → exercise-tracker

**DevOps**:
- basic-setup → server-management → bulk-operations

**Project Managers**:
- basic-setup → tenant-management → exercise-tracker

## Integration with Documentation

Examples reference detailed documentation for deeper learning:

```bash
# Learn more about any command:
monk docs <area>

# Examples:
monk docs auth      # Authentication documentation
monk docs data      # Data operations documentation
monk docs project   # Project management documentation
```

## Best Practices

### **Learning Approach**
- **Follow sequentially**: Each example builds on previous concepts
- **Experiment freely**: Modify commands to see different results
- **Check status often**: Use `monk status` to verify your state
- **Read the output**: Understand what each command returns

### **Environment Management**
```bash
# Create a dedicated learning environment
monk project init "Learning Sandbox" --create-user learner --auto-login

# Work in this environment for all examples
monk project use "Learning Sandbox"
```

### **Progress Tracking**
```bash
# After completing each example, save your work
monk data export users ./backup/
monk describe select users > users-schema-backup.json
```

## Troubleshooting

### **Common Issues**

**Server Connection**:
```bash
# Verify server is running
monk server ping

# Check server configuration
monk server list
```

**Authentication Problems**:
```bash
# Check authentication status
monk auth status

# Re-authenticate if needed
monk auth login <tenant> <username>
```

**Permission Issues**:
```bash
# Verify user permissions
monk auth info

# Check project access
monk project show <project-name>
```

### **Getting Help**
```bash
# Get help with any command
monk <command> --help

# View documentation
monk docs <area>

# Check current status for debugging
monk status
```

---

The `monk examples` command provides **guided learning paths** for mastering Monk CLI, from basic setup to advanced enterprise workflows. Start with `basic-setup` and progress through examples at your own pace.