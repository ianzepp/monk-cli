# Tenant Management

Learn how to create, list, switch between, and manage tenants within your Monk API server.

## Prerequisites
- Monk CLI configured and connected to a server
- Admin access to create/manage tenants

## Tenant Concepts

**Tenants** are isolated workspaces within a Monk API server. Each tenant:
- Has its own data schemas and records
- Has separate authentication contexts
- Can have different user roles and permissions
- Is completely isolated from other tenants

## Basic Tenant Operations

### List All Tenants
```bash
monk tenant list
```
Shows all tenants available on the current server.

### Create a New Tenant
```bash
monk tenant add myproject "My Project Description"
monk tenant add ecommerce "E-commerce Platform"
monk tenant add blog "Company Blog"
```

### Switch Between Tenants
```bash
monk tenant use myproject
monk tenant use ecommerce
monk tenant use blog
```

### Check Current Tenant
```bash
monk tenant current
```

### Remove a Tenant
```bash
monk tenant delete old-project
```

## Multi-Tenant Workflows

### Development Environment Setup
```bash
# Create separate tenants for different projects
monk tenant add dev-frontend "Frontend Development"
monk tenant add dev-backend "Backend Development"
monk tenant add staging "Staging Environment"
monk tenant add prod "Production Environment"

# Switch between them as needed
monk tenant use dev-frontend
# Work on frontend data...

monk tenant use dev-backend
# Work on backend data...
```

### Project-Based Organization
```bash
# Each project gets its own tenant
monk tenant add fitness-app "Personal Fitness Tracker"
monk tenant add inventory-sys "Inventory Management System"
monk tenant add crm "Customer Relationship Management"

# Switch contexts easily
monk tenant use fitness-app
monk data select users  # Fitness app users

monk tenant use crm
monk data select users  # CRM contacts (different schema)
```

## Authentication Across Tenants

### Tenant-Specific Login
```bash
# Login to different tenants with different credentials
monk tenant use fitness-app
monk auth login fitness-app admin

monk tenant use crm
monk auth login crm manager
```

### Cross-Tenant Operations
```bash
# Use path-based routing for cross-tenant access
monk fs ls /tenant/fitness-app/data/
monk fs cat /tenant/crm/data/users/user-123.json
```

## Best Practices

### Naming Conventions
```bash
# Use consistent prefixes
monk tenant add prod-website "Production Website"
monk tenant add dev-website "Development Website"
monk tenant add test-website "Testing Website"

# Or use descriptive names
monk tenant add fitness-tracker "Personal Fitness Tracking App"
monk tenant add expense-manager "Business Expense Management"
```

### Environment Separation
```bash
# Create tenant sets for each environment
# Development
monk tenant add dev-api "API Development"
monk tenant add dev-web "Web Development"
monk tenant add dev-mobile "Mobile Development"

# Production
monk tenant add prod-api "API Production"
monk tenant add prod-web "Web Production"
monk tenant add prod-mobile "Mobile Production"
```

### Backup and Recovery
```bash
# Export tenant data before major changes
monk data export users /backup/users-$(date +%Y%m%d).json

# Import data to new tenant
monk tenant add new-project "New Project"
monk tenant use new-project
monk data import users /backup/users-20241201.json
```

## Troubleshooting

### Permission Issues
```bash
# Check your current authentication
monk auth status

# Re-authenticate if needed
monk auth login mytenant admin
```

### Tenant Not Found
```bash
# List available tenants
monk tenant list

# Check current server
monk server current

# Switch servers if needed
monk server use correct-server
```

### Cross-Tenant Access
```bash
# Use full paths for cross-tenant operations
monk fs ls /tenant/other-tenant/data/

# Check tenant permissions
monk auth status
```

## Next Steps
- `monk examples data-crud` - Learn basic data operations
- `monk examples schema-creation` - Define data structures
- `monk examples bulk-operations` - Work with large datasets</content>
<parameter name="filePath">/Users/ianzepp/Workspaces/monk-cli/examples/tenant-management.md