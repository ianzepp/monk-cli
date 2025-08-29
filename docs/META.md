# Meta Commands Documentation

## Overview

The `monk meta` commands provide **schema and metadata management** for dynamic database schemas. These commands interact with the `/api/meta/*` endpoints to create, retrieve, update, and delete JSON Schema definitions that automatically generate database tables.

**Format Note**: Meta commands work exclusively with **YAML format** as schemas are configuration definitions. Text and JSON format flags are not supported.

## Command Structure

```bash
monk meta <operation> <type> [name] [flags]
```

**Currently Supported Type**: `schema`

## Available Commands

### **Schema Management**

#### **Retrieve Schema Definition**
```bash
monk meta select schema <name>
```

**Examples:**
```bash
# Get users schema definition
monk meta select schema users

# Save schema to file
monk meta select schema users > users.yaml

# Pipe to other tools
monk meta select schema products | yq '.properties.name'
```

**Sample Output:**
```yaml
name: users
type: object
properties:
  id:
    type: string
    format: uuid
  name:
    type: string
    minLength: 1
    maxLength: 100
  email:
    type: string
    format: email
  created_at:
    type: string
    format: date-time
required:
  - name
  - email
additionalProperties: false
```

#### **Create New Schema**
```bash
monk meta create schema
```

**Usage:**
```bash
# Create from file
cat user-schema.yaml | monk meta create schema

# Create from inline YAML
cat << 'EOF' | monk meta create schema
name: products
type: object
properties:
  id:
    type: string
    format: uuid
  name:
    type: string
    minLength: 1
  price:
    type: number
    minimum: 0
required:
  - name
  - price
EOF
```

**What Happens:**
1. Validates YAML syntax and JSON Schema specification
2. Creates PostgreSQL database table with generated DDL
3. Adds schema to metadata registry
4. Enables data operations on the new schema

#### **Update Existing Schema**
```bash
monk meta update schema <name>
```

**Examples:**
```bash
# Update schema from file
cat updated-users.yaml | monk meta update schema users

# Add new field to existing schema
cat << 'EOF' | monk meta update schema users
name: users
type: object
properties:
  id:
    type: string
    format: uuid
  name:
    type: string
  email:
    type: string
    format: email
  phone:
    type: string
    pattern: "^\\+?[1-9]\\d{1,14}$"
  created_at:
    type: string
    format: date-time
required:
  - name
  - email
EOF
```

**Schema Updates:**
- Automatically generates `ALTER TABLE` statements for database changes
- Adds new columns for new properties
- Updates column constraints for modified properties
- Preserves existing data during schema evolution

#### **Delete Schema**
```bash
monk meta delete schema <name>
```

**Examples:**
```bash
# Soft delete schema (recoverable)
monk meta delete schema test-schema

# Verbose mode shows confirmation prompt
CLI_VERBOSE=true monk meta delete schema users
```

**Deletion Process:**
- Soft deletes schema definition (preserves data)
- Marks database table as deleted
- Removes from schema cache
- Hides from normal operations

## Schema Definition Format

Meta commands use **JSON Schema** specification in YAML format:

### **Basic Schema Template**
```yaml
name: example_schema
type: object
title: "Example Schema"
description: "A sample schema for demonstration"

properties:
  id:
    type: string
    format: uuid
    description: "Unique identifier"
    
  name:
    type: string
    minLength: 1
    maxLength: 100
    description: "Display name"
    
  status:
    type: string
    enum: ["active", "inactive", "pending"]
    default: "pending"
    
  metadata:
    type: object
    additionalProperties: true
    
  created_at:
    type: string
    format: date-time
    readOnly: true

required:
  - name

additionalProperties: false
```

### **Supported JSON Schema Features**
- **Types**: string, number, integer, boolean, object, array
- **Formats**: uuid, email, date-time, uri, etc.
- **Validation**: minLength, maxLength, minimum, maximum, pattern
- **Constraints**: enum, const, required fields
- **Composition**: allOf, oneOf, anyOf, not
- **References**: $ref for schema reuse

## Format Restrictions

Meta commands **only support YAML format**:

```bash
# ✅ Correct usage
monk meta select schema users
cat schema.yaml | monk meta create schema

# ❌ Invalid format flags
monk --text meta select schema users
# Error: The --text option is not supported for meta operations
# Meta operations work with YAML schema definitions

monk --json meta create schema
# Error: The --json option is not supported for meta operations  
# Meta operations work with YAML schema definitions
```

## Integration with Data Operations

Once schemas are defined via meta commands, use data commands for records:

```bash
# 1. Define schema structure
cat user-schema.yaml | monk meta create schema

# 2. Work with data records  
echo '{"name": "Alice", "email": "alice@example.com"}' | monk data create users
monk data select users
```

## Error Handling

Meta commands provide comprehensive error validation:

### **Schema Validation Errors**
```bash
# Invalid YAML syntax
cat invalid.yaml | monk meta create schema
# Error: Invalid YAML syntax at line 5

# Missing required fields
cat incomplete.yaml | monk meta create schema
# Error: Schema missing required 'name' field
```

### **Database Errors**
```bash
# Schema conflicts
cat conflicting.yaml | monk meta update schema users
# Error: Cannot remove required field 'email' - existing data would become invalid
```

### **System Protection**
```bash
# Protected schemas
monk meta delete schema _system
# Error: System schemas cannot be deleted
```

## Best Practices

1. **Version Control**: Store schema definitions in version control
2. **Validation**: Test schema changes in development before production
3. **Backwards Compatibility**: Avoid removing required fields from existing schemas
4. **Documentation**: Use title and description fields for schema documentation
5. **Naming**: Use clear, descriptive schema names (lowercase, underscores for separation)

## Advanced Features

### **Schema Relationships**
```yaml
name: orders
type: object
properties:
  id:
    type: string
    format: uuid
  user_id:
    type: string
    format: uuid
    description: "Reference to users.id"
  items:
    type: array
    items:
      type: object
      properties:
        product_id:
          type: string
          format: uuid
        quantity:
          type: integer
          minimum: 1
```

### **Custom Validation**
```yaml
name: products
type: object
properties:
  price:
    type: number
    minimum: 0
    multipleOf: 0.01
  sku:
    type: string
    pattern: "^[A-Z]{3}-\\d{6}$"
  tags:
    type: array
    items:
      type: string
    uniqueItems: true
    maxItems: 10
```

Meta commands provide powerful schema management capabilities while maintaining the flexibility and validation benefits of JSON Schema specification.