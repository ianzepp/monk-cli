# Describe Commands Documentation

## Overview

The `monk describe` commands provide **schema description and management** for dynamic database schemas. These commands interact with the `/api/describe/*` endpoints to create, retrieve, update, and delete JSON Schema definitions that automatically generate database tables.

**Format Note**: Describe commands work exclusively with **JSON format** as schemas are configuration definitions. Text and JSON format flags are supported for output formatting.

## Command Structure

```bash
monk describe <operation> <schema-name> [flags]
```

## Available Commands

### **Schema Management**

#### **List All Schemas**
```bash
monk describe list
```

**Examples:**
```bash
# List all schemas in text format
monk describe list

# List all schemas in JSON format
monk --json describe list

# Count total schemas
monk describe list | wc -l
```

**Sample Output (Text):**
```
✓ Success (200)
schemas
users
products
orders
test_schema
```

**Sample Output (JSON):**
```json
✓ Success (200)
["schemas","users","products","orders","test_schema"]
```

**Use Cases:**
- Discover available schemas in a tenant
- Verify schema creation
- Build automation scripts
- Generate schema documentation

#### **Retrieve Schema Definition**
```bash
monk describe select <name>
```

**Examples:**
```bash
# Get users schema definition
monk describe select users

# Save schema to file
monk describe select users > users.json

# Pipe to other tools
monk describe select products | jq '.properties.name'
```

**Sample Output:**
```json
{
  "title": "users",
  "type": "object",
  "properties": {
    "id": {
      "type": "string",
      "format": "uuid"
    },
    "name": {
      "type": "string",
      "minLength": 1,
      "maxLength": 100
    },
    "email": {
      "type": "string",
      "format": "email"
    },
    "access": {
      "type": "string",
      "enum": ["root", "full", "edit", "read", "deny"]
    }
  },
  "required": ["id", "name", "email", "access"]
}
```

#### **Create New Schema**
```bash
echo '<json-schema>' | monk describe create <name>
```

**Examples:**
```bash
# Create from file
cat user-schema.json | monk describe create users

# Create from inline JSON
echo '{
  "title": "users",
  "type": "object",
  "properties": {
    "name": {"type": "string", "minLength": 1},
    "email": {"type": "string", "format": "email"},
    "role": {"type": "string", "enum": ["admin", "user"]}
  },
  "required": ["name", "email"]
}' | monk describe create users

# Create with validation
echo '{
  "title": "products",
  "type": "object",
  "properties": {
    "name": {"type": "string", "minLength": 1, "maxLength": 200},
    "price": {"type": "number", "minimum": 0, "maximum": 10000},
    "category": {"type": "string", "enum": ["electronics", "books", "clothing"]},
    "in_stock": {"type": "boolean", "default": true}
  },
  "required": ["name", "price", "category"]
}' | monk describe create products
```

#### **Update Existing Schema**
```bash
echo '<updated-json-schema>' | monk describe update <name>
```

**Examples:**
```bash
# Update from file
cat updated-users.json | monk describe update users

# Add new fields
echo '{
  "title": "users",
  "type": "object",
  "properties": {
    "name": {"type": "string", "minLength": 1, "maxLength": 100},
    "email": {"type": "string", "format": "email"},
    "role": {"type": "string", "enum": ["admin", "user", "moderator"]},
    "department": {"type": "string", "description": "User department"},
    "active": {"type": "boolean", "default": true}
  },
  "required": ["name", "email"]
}' | monk describe update users

# Update with complex validation
echo '{
  "title": "products",
  "properties": {
    "sku": {"type": "string", "pattern": "^[A-Z]{3}-[0-9]{6}$"},
    "tags": {
      "type": "array",
      "items": {"type": "string", "maxLength": 50},
      "maxItems": 10
    },
    "dimensions": {
      "type": "object",
      "properties": {
        "width": {"type": "number", "minimum": 0},
        "height": {"type": "number", "minimum": 0},
        "depth": {"type": "number", "minimum": 0}
      }
    }
  }
}' | monk describe update products
```

#### **Delete Schema (Soft Delete)**
```bash
monk describe delete <name>
```

**Examples:**
```bash
# Delete a test schema
monk describe delete test-schema

# Delete with verbose output
CLI_VERBOSE=true monk describe delete old-products

# Delete and verify
monk describe delete deprecated-users
# Schema is soft-deleted and can be restored via API
```

## JSON Schema Support

### Supported Property Types

| Type | PostgreSQL Mapping | Example |
|------|-------------------|---------|
| string | TEXT or VARCHAR | `{"type": "string", "maxLength": 255}` |
| integer | INTEGER | `{"type": "integer", "minimum": 0}` |
| number | DECIMAL | `{"type": "number", "multipleOf": 0.01}` |
| boolean | BOOLEAN | `{"type": "boolean", "default": false}` |
| array | JSONB | `{"type": "array", "items": {"type": "string"}}` |
| object | JSONB | `{"type": "object", "properties": {...}}` |

### String Formats

| Format | Validation | PostgreSQL Type |
|--------|------------|-----------------|
| email | Email validation | TEXT |
| uuid | UUID format | UUID |
| date-time | ISO 8601 timestamp | TIMESTAMP |

### Validation Keywords

- **String**: `minLength`, `maxLength`, `pattern`, `enum`
- **Number**: `minimum`, `maximum`, `multipleOf`
- **Array**: `minItems`, `maxItems`, `uniqueItems`
- **All types**: `default`, `description`

## System Fields

All schemas automatically include system-managed fields:

| Field | Type | Purpose |
|-------|------|---------|
| id | UUID | Primary key (auto-generated) |
| access_read | UUID[] | Read access control list |
| access_edit | UUID[] | Edit access control list |
| access_full | UUID[] | Full access control list |
| access_deny | UUID[] | Deny access control list |
| created_at | TIMESTAMP | Record creation time |
| updated_at | TIMESTAMP | Last modification time |
| trashed_at | TIMESTAMP | Soft delete timestamp |
| deleted_at | TIMESTAMP | Hard delete timestamp |

## Protected Schemas

System schemas cannot be modified or deleted:

- **users** - User account management
- **schema** - Schema metadata registry

## Schema Lifecycle

### Development Workflow

```bash
# 1. Create schema
echo '{"title": "products", "properties": {...}}' | monk describe create products

# 2. Add data using Data API
echo '[{"name": "Laptop", "price": 999.99}]' | monk data create products

# 3. Update schema as needed
echo '{"title": "products", "properties": {"name": {...}, "sku": {...}}}' | monk describe update products

# 4. Query data with new structure
monk data list products
```

### Schema Evolution Best Practices

- **Additive changes**: New fields can be added safely
- **Validation updates**: Constraint changes are validated against existing data
- **Breaking changes**: Removing required fields may affect existing data
- **Soft delete**: Schemas can be deleted and restored via API

## Error Handling

### Common Errors

```bash
# Invalid JSON
$ echo 'invalid json' | monk describe create test
✗ Invalid JSON input

# Missing title field
$ echo '{"properties": {"name": {"type": "string"}}}' | monk describe create test
✗ JSON schema must have a 'title' field

# Protected schema
$ monk describe update users
✗ HTTP 403 - Schema 'users' is protected and cannot be modified

# Non-existent schema
$ monk describe select nonexistent
✗ HTTP Error (404) - Schema 'nonexistent' not found
```

## Output Formats

### Text Format (Default)
```bash
monk describe select users
# Returns formatted JSON schema
```

### JSON Format
```bash
monk --json describe select users
# Returns compact JSON: {"title":"users","type":"object","properties":{...}}
```

## Advanced Examples

### Complete Product Catalog Schema
```bash
echo '{
  "title": "products",
  "description": "Complete product catalog with inventory tracking",
  "properties": {
    "name": {
      "type": "string",
      "minLength": 1,
      "maxLength": 200,
      "description": "Product name"
    },
    "sku": {
      "type": "string",
      "pattern": "^[A-Z]{3}-[0-9]{6}$",
      "description": "Stock keeping unit"
    },
    "price": {
      "type": "number",
      "minimum": 0,
      "maximum": 10000,
      "description": "Product price in USD"
    },
    "category": {
      "type": "string",
      "enum": ["electronics", "books", "clothing", "home", "sports"],
      "description": "Product category"
    },
    "tags": {
      "type": "array",
      "items": {
        "type": "string",
        "maxLength": 50
      },
      "maxItems": 10,
      "description": "Product tags for categorization"
    },
    "dimensions": {
      "type": "object",
      "properties": {
        "width": {"type": "number", "minimum": 0},
        "height": {"type": "number", "minimum": 0},
        "depth": {"type": "number", "minimum": 0},
        "weight": {"type": "number", "minimum": 0}
      },
      "description": "Product dimensions"
    },
    "manufacturer": {
      "type": "string",
      "description": "Product manufacturer"
    },
    "warranty_months": {
      "type": "integer",
      "minimum": 0,
      "maximum": 120,
      "description": "Warranty period in months"
    },
    "in_stock": {
      "type": "boolean",
      "default": true,
      "description": "Stock availability"
    }
  },
  "required": ["name", "sku", "price", "category"]
}' | monk describe create products
```

### User Management Schema
```bash
echo '{
  "title": "users",
  "description": "User management with profile and preferences",
  "properties": {
    "username": {
      "type": "string",
      "pattern": "^[a-zA-Z0-9_]{3,20}$",
      "description": "Unique username"
    },
    "email": {
      "type": "string",
      "format": "email",
      "description": "Email address"
    },
    "profile": {
      "type": "object",
      "properties": {
        "first_name": {"type": "string", "maxLength": 50},
        "last_name": {"type": "string", "maxLength": 50},
        "bio": {"type": "string", "maxLength": 500},
        "avatar": {"type": "string", "format": "uri"}
      }
    },
    "preferences": {
      "type": "object",
      "properties": {
        "theme": {"type": "string", "enum": ["light", "dark", "auto"]},
        "language": {"type": "string", "pattern": "^[a-z]{2}-[A-Z]{2}$"},
        "notifications": {"type": "boolean"}
      }
    },
    "metadata": {
      "type": "object",
      "description": "Additional user metadata"
    }
  },
  "required": ["username", "email"]
}' | monk describe create users
```

## When to Use Describe API

**Use Describe API when:**
- Defining new data structures and validation rules
- Managing schema evolution and data model changes
- Setting up new applications or modules
- Implementing dynamic form generation
- Creating reusable data models

**Use Data API when:**
- Working with records in existing schemas
- CRUD operations on structured data
- Bulk data operations and migrations

**Use File API when:**
- Exploring schema structures and relationships
- Individual field access and manipulation
- Filesystem-like navigation of data

## Related Documentation

- **[DATA.md](DATA.md)** - Working with records in defined schemas
- **[FILE.md](FILE.md)** - Filesystem-like access to schemas and data
- **[BULK.md](BULK.md)** - Batch schema and record operations
- **[FIND.md](FIND.md)** - Complex queries across schema data

The Describe API provides the foundation for all data operations by defining the structure, validation rules, and relationships that govern your application's data model.