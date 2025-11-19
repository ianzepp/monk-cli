# Schema and Data Management

Learn how to define schemas and work with data in your Monk API tenant. Schema management (describe) and data operations work together to provide a complete data management solution.

## Prerequisites
- Monk CLI configured and authenticated
- Server and tenant selected
- Basic understanding of JSON Schema

## Overview

Monk CLI provides two closely related command groups:

- **`monk describe`** - Define and manage schemas (structure and validation)
- **`monk data`** - Create, read, update, and delete records (content)

Think of schemas as your database table definitions, and data as the rows in those tables.

## Schema Management with `describe`

### List All Schemas
```bash
monk describe list
```

Output:
```
users
products
orders
```

### Create a Schema

Define a schema for user records:

```bash
echo '{
  "type": "object",
  "title": "users",
  "properties": {
    "name": {
      "type": "string",
      "minLength": 1,
      "maxLength": 100
    },
    "email": {
      "type": "string",
      "format": "email"
    },
    "role": {
      "type": "string",
      "enum": ["admin", "user", "moderator"]
    },
    "active": {
      "type": "boolean",
      "default": true
    }
  },
  "required": ["name", "email", "role"]
}' | monk describe create users
```

### View a Schema Definition
```bash
monk describe get users
```

### Update a Schema

Add a new field to the users schema:

```bash
echo '{
  "type": "object",
  "title": "users",
  "properties": {
    "name": {"type": "string", "minLength": 1, "maxLength": 100},
    "email": {"type": "string", "format": "email"},
    "role": {"type": "string", "enum": ["admin", "user", "moderator"]},
    "active": {"type": "boolean", "default": true},
    "department": {"type": "string"},
    "last_login": {"type": "string", "format": "date-time"}
  },
  "required": ["name", "email", "role"]
}' | monk describe update users
```

### Delete a Schema
```bash
monk describe delete users
```

Note: This is a soft delete. The schema can be restored via the API.

## Data Operations with `data`

Once you have a schema defined, you can work with data.

### List All Records
```bash
# List all users
monk data list users

# Get a specific user by ID
monk data get users user-123
```

### Create Records

#### Create a Single Record
```bash
echo '{
  "name": "John Doe",
  "email": "john@example.com",
  "role": "admin",
  "active": true
}' | monk data create users
```

#### Create Multiple Records
```bash
echo '[
  {
    "name": "Jane Smith",
    "email": "jane@example.com",
    "role": "user"
  },
  {
    "name": "Bob Johnson",
    "email": "bob@example.com",
    "role": "moderator"
  }
]' | monk data create users
```

### Update Records

#### Update by ID
```bash
echo '{
  "department": "engineering",
  "last_login": "2024-12-15T14:30:00Z"
}' | monk data update users user-123
```

#### Update Multiple Records with Filter
```bash
echo '{
  "active": false
}' | monk data update users --filter '{"role": "user"}'
```

### Delete Records

#### Delete by ID
```bash
monk data delete users user-123
```

#### Delete with Filter
```bash
# Delete inactive users
monk data delete users --filter '{"active": false}'
```

## Complete Workflow Example

Let's create a product catalog from scratch:

### Step 1: Define the Products Schema
```bash
echo '{
  "type": "object",
  "title": "products",
  "properties": {
    "name": {
      "type": "string",
      "minLength": 1,
      "maxLength": 200
    },
    "description": {
      "type": "string",
      "maxLength": 1000
    },
    "price": {
      "type": "number",
      "minimum": 0
    },
    "category": {
      "type": "string",
      "enum": ["electronics", "books", "clothing", "home"]
    },
    "in_stock": {
      "type": "boolean",
      "default": true
    },
    "tags": {
      "type": "array",
      "items": {"type": "string"}
    }
  },
  "required": ["name", "price", "category"]
}' | monk describe create products
```

### Step 2: Verify the Schema
```bash
monk describe list
monk describe get products
```

### Step 3: Add Products
```bash
echo '{
  "name": "Wireless Headphones",
  "description": "Premium noise-canceling headphones",
  "price": 199.99,
  "category": "electronics",
  "in_stock": true,
  "tags": ["audio", "wireless", "premium"]
}' | monk data create products
```

### Step 4: List Products
```bash
monk data list products
```

### Step 5: Update a Product
```bash
echo '{
  "price": 179.99,
  "in_stock": true
}' | monk data update products product-123
```

### Step 6: Query Products
```bash
# Find electronics
monk find products <<< '{"where": {"category": "electronics"}}'

# Find products under $100
monk find products <<< '{"where": {"price": {"$lt": 100}}}'
```

## Working with Complex Data

### Nested Objects
```bash
# Schema with nested specs
echo '{
  "type": "object",
  "title": "products",
  "properties": {
    "name": {"type": "string"},
    "specs": {
      "type": "object",
      "properties": {
        "weight": {"type": "string"},
        "dimensions": {"type": "string"},
        "color": {"type": "string"}
      }
    }
  }
}' | monk describe create products

# Create product with nested data
echo '{
  "name": "Laptop",
  "specs": {
    "weight": "1.5kg",
    "dimensions": "30x20x2cm",
    "color": "silver"
  }
}' | monk data create products
```

### Arrays
```bash
# Schema with array field
echo '{
  "type": "object",
  "title": "posts",
  "properties": {
    "title": {"type": "string"},
    "tags": {
      "type": "array",
      "items": {"type": "string"},
      "maxItems": 10
    },
    "comments": {
      "type": "array",
      "items": {
        "type": "object",
        "properties": {
          "user": {"type": "string"},
          "text": {"type": "string"}
        }
      }
    }
  }
}' | monk describe create posts
```

## Best Practices

### Schema Design
1. **Start Simple** - Begin with basic fields, add complexity as needed
2. **Use Validation** - Add `minLength`, `maxLength`, `enum`, `pattern` constraints
3. **Document Fields** - Use `description` property to explain field purpose
4. **Plan for Evolution** - Schemas can be updated, but plan carefully

### Data Operations
1. **Validate First** - Check schema before creating data
2. **Use Filters** - More efficient than fetching all records
3. **Batch Operations** - Use `monk data create` with arrays for multiple records
4. **Check Results** - Always verify operations completed successfully

## Common Patterns

### User Management System
```bash
# Define schema
echo '{
  "type": "object",
  "title": "users",
  "properties": {
    "username": {"type": "string", "minLength": 3, "maxLength": 20},
    "email": {"type": "string", "format": "email"},
    "role": {"type": "string", "enum": ["admin", "user"]},
    "active": {"type": "boolean", "default": true},
    "created_at": {"type": "string", "format": "date-time"}
  },
  "required": ["username", "email", "role"]
}' | monk describe create users

# Add users
echo '[
  {"username": "alice", "email": "alice@company.com", "role": "admin"},
  {"username": "bob", "email": "bob@company.com", "role": "user"}
]' | monk data create users

# List all users
monk data list users

# Find admins
monk find users <<< '{"where": {"role": "admin"}}'
```

## Data Import/Export

### Export Schema and Data
```bash
# Export schema definition
monk describe get users > users-schema.json

# Export all data
monk data list users > users-data.json
```

### Import to Another Tenant
```bash
# Switch tenant
monk config tenant use production

# Import schema
cat users-schema.json | monk describe create users

# Import data
cat users-data.json | monk data create users
```

## Troubleshooting

### Schema Issues
```bash
# List all schemas
monk describe list

# Check schema definition
monk describe get users

# Verify schema is valid JSON
monk describe get users | jq .
```

### Data Issues
```bash
# Verify data structure matches schema
monk describe get users
monk data list users | jq '.[0]'

# Check for validation errors in output
```

## Next Steps
- `monk examples getting-started` - Basic setup and first steps
- `monk examples find` - Advanced search and filtering (coming soon)
- `monk examples bulk` - Bulk operations for large datasets (coming soon)
