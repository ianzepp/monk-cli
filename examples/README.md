# Monk CLI Examples

This directory contains practical examples and workflows for using Monk CLI effectively.

## Available Examples

### **🚀 Quick Start**
- **[Basic Setup](basic-setup.md)** - Initial configuration and first connection
- **[Server Management](server-management.md)** - Multi-server setup and management
- **[Tenant Management](tenant-management.md)** - Traditional tenant administration

### **🏗️ Project-Based Workflows**
- **[Exercise Tracker Project](exercise-tracker-project.md)** - Complete project example with schema design and data operations
- **[Data CRUD Operations](data-crud.md)** - Basic data manipulation examples

### **📊 Advanced Features**
- **[Bulk Operations](bulk-operations.md)** - Batch processing and bulk data operations

## Recommended Learning Path

### **For New Users**
1. **[Basic Setup](basic-setup.md)** - Get started with CLI configuration
2. **[Exercise Tracker Project](exercise-tracker-project.md)** - Complete project workflow (recommended)
3. **[Data CRUD Operations](data-crud.md)** - Learn data manipulation basics

### **For Traditional Setup**
1. **[Basic Setup](basic-setup.md)** - Initial configuration
2. **[Server Management](server-management.md)** - Multi-environment setup
3. **[Tenant Management](tenant-management.md)** - Traditional tenant workflow
4. **[Data CRUD Operations](data-crud.md)** - Data operations

### **For Advanced Users**
1. All basic examples
2. **[Bulk Operations](bulk-operations.md)** - Batch processing
3. **[Exercise Tracker Project](exercise-tracker-project.md)** - Real-world application patterns

## Example Categories

### **🎯 Project Examples**
Complete, realistic applications demonstrating:
- **Project Creation** - Using `monk project init` for rapid setup
- **Schema Design** - Database modeling with JSON schemas
- **Data Operations** - CRUD operations and relationships
- **Query Patterns** - Various ways to retrieve data
- **Filesystem Interface** - Unix-like data exploration

### **🔧 Technical Examples**
Specific feature demonstrations:
- **Authentication** - User management and JWT tokens
- **Multi-tenancy** - Tenant isolation and switching
- **Data Validation** - Schema enforcement and constraints
- **API Integration** - HTTP client patterns

### **📋 Workflow Examples**
Common development patterns:
- **Development Setup** - Local development environment
- **Testing Workflows** - Data setup for testing
- **Backup/Restore** - Data export and import
- **Migration** - Schema and data migration

## Running Examples

### **Prerequisites**
```bash
# Install Monk CLI (if not already installed)
./install.sh

# Initialize CLI configuration
monk init

# Add your server
monk server add local localhost:9001
monk server use local
```

### **Quick Test**
```bash
# Test server connection
monk server ping

# Create a test project
monk project init "Test Project" --create-user admin --auto-login

# Verify setup
monk status
```

## Example Features

### **Copy-Paste Ready**
All examples include:
- ✅ Complete command sequences
- ✅ Expected output samples
- ✅ Error handling guidance
- ✅ Cleanup instructions

### **Realistic Scenarios**
Examples demonstrate:
- 🏃‍♂️ Exercise tracking application
- 💼 Business data management
- 🔍 Search and filtering patterns
- 📈 Analytics and reporting

### **Best Practices**
Each example shows:
- 🎯 Proper schema design
- 🔐 Security considerations
- 📝 Documentation patterns
- 🧪 Testing approaches

## Contributing Examples

To contribute new examples:

1. **Create new file** in this directory
2. **Follow naming convention** - `kebab-case.md`
3. **Include sections**:
   - Overview/Goals
   - Prerequisites
   - Step-by-step instructions
   - Expected outputs
   - Cleanup/Next steps
4. **Test thoroughly** - Verify all commands work
5. **Update this index** - Add your example to the list

### **Example Template**
```markdown
# Example Title

Brief description of what this example demonstrates.

## Goals
- Goal 1
- Goal 2

## Prerequisites
- Requirement 1
- Requirement 2

## Steps
### Step 1: Description
```bash
# Commands here
```

### Step 2: Description
```bash
# More commands
```

## Expected Output
Show what users should see.

## Cleanup
```bash
# Cleanup commands
```

## Next Steps
What to learn next.
```

## Getting Help

If you have issues with examples:

1. **Check prerequisites** - Ensure Monk API is running
2. **Verify configuration** - Use `monk status` to check setup
3. **Review logs** - Use `CLI_VERBOSE=true monk <command>` for debugging
4. **Check documentation** - See `docs/` directory for detailed guides
5. **Report issues** - File GitHub issues with example name and error details

---

**Start with the [Exercise Tracker Project](exercise-tracker-project.md) for the most comprehensive learning experience!** 🚀