# Reading API Documentation

Learn how to discover and read API documentation directly from your Monk API server using the `monk docs` command.

## Prerequisites
- Monk CLI configured
- Server connection established
- Server running and accessible

## Overview

The `monk docs` command provides access to comprehensive API documentation served directly from your Monk API server. This ensures you're always reading documentation that matches your server's version and capabilities.

## Quick Start

### View Available Documentation Areas

The API organizes documentation into different areas based on functionality:

```bash
monk docs home
```

This shows the API overview and lists all available documentation areas.

### Common Documentation Areas

- **auth** - Authentication and user management
- **data** - Data CRUD operations
- **describe** - Schema management
- **find** - Advanced search and filtering
- **bulk** - Bulk operations
- **file** - File API (filesystem-like access)
- **acls** - Access control lists
- **root** - Administrative operations

## Reading Documentation

### Authentication API
```bash
monk docs auth
```

This displays comprehensive documentation about:
- `POST /auth/register` - Register new tenant and user
- `POST /auth/login` - Authenticate with credentials
- `POST /auth/refresh` - Refresh JWT token
- `GET /api/auth/whoami` - Get current user info
- `GET /api/auth/sudo` - Administrative access

### Data API
```bash
monk docs data
```

Learn about:
- `GET /api/data/:schema` - List all records
- `GET /api/data/:schema/:record` - Get specific record
- `POST /api/data/:schema` - Create new records
- `PUT /api/data/:schema/:record` - Update records
- `DELETE /api/data/:schema/:record` - Delete records

### Schema Management API
```bash
monk docs describe
```

Documentation includes:
- `GET /api/describe` - List all schemas
- `GET /api/describe/:schema` - Get schema definition
- `POST /api/describe/:schema` - Create new schema
- `PUT /api/describe/:schema` - Update schema
- `DELETE /api/describe/:schema` - Delete schema

### Advanced Search API
```bash
monk docs find
```

Learn about the powerful Filter DSL for complex queries.

### Bulk Operations API
```bash
monk docs bulk
```

Documentation for batch processing operations.

### File API
```bash
monk docs file
```

Filesystem-like operations for exploring data and schemas.

### Access Control API
```bash
monk docs acls
```

Documentation for managing access control lists.

### Administrative API
```bash
monk docs root
```

Root-level operations for tenant management (localhost only).

## Output Formats

### Default: Formatted View (glow)

By default, documentation is rendered with `glow` for enhanced markdown formatting:

```bash
monk docs auth
```

This provides:
- Syntax highlighting
- Formatted tables
- Easy navigation
- Pager for long documents

### Text Format (Raw Markdown)

For piping to other tools or viewing in editors:

```bash
monk --text docs auth
```

This outputs raw markdown without formatting, useful for:
- Saving to files
- Processing with other tools
- Quick searching

### Saving Documentation

```bash
# Save to file
monk --text docs auth > auth-api-docs.md

# Search within documentation
monk --text docs data | grep "POST"

# Count endpoints
monk --text docs describe | grep "^##" | wc -l
```

## Discovering API Capabilities

### Step 1: Check Server Information
```bash
monk config server info
```

This shows the server version and available endpoints.

### Step 2: View API Overview
```bash
monk docs home
```

Lists all documentation areas available on your server.

### Step 3: Read Specific Documentation
```bash
monk docs describe
```

Deep dive into the area you're working with.

### Step 4: Test Endpoints

After reading the docs, test the endpoints:

```bash
# Example from describe docs
monk describe list
monk describe select users
```

## Practical Examples

### Example 1: Learning About Data Operations

```bash
# Read the data API documentation
monk docs data

# Try the endpoints
monk data list users
monk data list users user-123
```

### Example 2: Understanding Authentication

```bash
# Read auth documentation
monk docs auth

# See your current auth status
monk auth status

# Check your JWT token
monk auth info
```

### Example 3: Exploring Schema Management

```bash
# Read describe documentation
monk docs describe

# List all schemas
monk describe list

# View a schema definition
monk describe select users
```

### Example 4: Advanced Querying

```bash
# Read find documentation
monk docs find

# Try a query
echo '{"where": {"status": "active"}}' | monk find users
```

## Tips and Tricks

### Quick Reference

Create a local docs cache for offline reference:

```bash
# Save all documentation areas
for area in auth data describe find bulk file acls root; do
  monk --text docs $area > ~/monk-docs-$area.md
done
```

### Search Across Documentation

```bash
# Find all POST endpoints
for area in auth data describe bulk file; do
  echo "=== $area ==="
  monk --text docs $area | grep "^### POST"
done
```

### Integration with Tools

```bash
# Convert to HTML
monk --text docs auth | pandoc -f markdown -t html > auth-docs.html

# Create PDF
monk --text docs describe | pandoc -f markdown -o describe-docs.pdf
```

## Understanding Documentation Structure

Each documentation area typically includes:

1. **Overview** - What the API area does
2. **Base Path** - URL prefix for endpoints
3. **Endpoint Summary** - Quick reference table
4. **Authentication** - Required auth level
5. **Endpoint Details** - Comprehensive info for each route:
   - HTTP method and path
   - Description
   - Request format
   - Response format
   - Examples
   - Error codes

## Working with Different Servers

Documentation is server-specific. When you switch servers, you may see different docs:

```bash
# Check docs on development server
monk config server use dev
monk docs data

# Check docs on production server
monk config server use production
monk docs data
```

Differences might include:
- Different API versions
- Additional endpoints
- Modified functionality
- New features

## Troubleshooting

### No Documentation Available

```bash
$ monk docs auth
✗ Documentation area 'auth' not found
```

**Solution:** Check available areas with `monk docs home`

### Server Not Responding

```bash
$ monk docs data
✗ Failed to fetch documentation
```

**Solution:** 
1. Verify server is running: `monk config server ping`
2. Check server info: `monk config server info`
3. Ensure you're connected: `monk status`

### Display Issues

If `glow` formatting doesn't look right:

```bash
# Use text format instead
monk --text docs auth

# Or install/update glow
brew install glow
```

## Best Practices

1. **Read First, Code Later** - Always check the docs before trying new endpoints
2. **Keep Reference Handy** - Save commonly used docs locally
3. **Check After Updates** - Re-read docs when server is updated
4. **Match Server Version** - Documentation matches your connected server
5. **Use Examples** - The docs include working examples you can copy

## Next Steps

- `monk examples getting-started` - Set up your first connection
- `monk examples describe-and-data` - Work with schemas and data
- `monk examples server-management` - Manage server connections

## Related Commands

```bash
monk config server info        # View server capabilities
monk status            # Check current connection
monk --help            # CLI command reference
monk describe list     # List available schemas
monk data list <schema> # List records in a schema
```

The `monk docs` command ensures you always have accurate, up-to-date documentation for the API you're working with!
