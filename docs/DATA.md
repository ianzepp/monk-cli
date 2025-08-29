# Data Commands Documentation

## Overview

The `monk data` commands provide **CRUD operations** for dynamic database schemas. These commands interact with the `/api/data/*` endpoints to create, retrieve, update, and delete records in tenant databases with intelligent array/object handling.

**Format Note**: Data commands work exclusively with **JSON format** for structured data operations. The `--text` flag is not supported for data manipulation operations.

## Command Structure

```bash
monk data <operation> <schema> [id] [flags]
```

## Available Commands

### **Data Selection and Retrieval**

#### **Select Records**
```bash
monk data select <schema> [id]
```

**Usage Patterns:**

**1. List All Records:**
```bash
monk data select users
```
```json
[{"id":"123","name":"Alice","email":"alice@example.com"},{"id":"456","name":"Bob","email":"bob@example.com"}]
```

**2. Get Specific Record:**
```bash
monk data select users 123
```
```json
{"id":"123","name":"Alice","email":"alice@example.com","created_at":"2025-08-29T10:30:00.000Z"}
```

**3. Query with Parameters:**
```bash
echo '{"limit": 10, "order": "name asc"}' | monk data select users
echo '{"limit": 5, "offset": 20}' | monk data select users
```

**4. Complex Queries (Redirects to Find):**
```bash
echo '{"where": {"status": "active"}, "limit": 10}' | monk data select users
# Automatically redirects to: monk find users
```

### **Data Manipulation**

#### **Create Records**
```bash
monk data create <schema>
```

**Single Record Creation:**
```bash
echo '{"name": "Charlie", "email": "charlie@example.com"}' | monk data create users
```
```json
{"id":"789","name":"Charlie","email":"charlie@example.com","created_at":"2025-08-29T10:35:00.000Z"}
```

**Bulk Record Creation:**
```bash
echo '[
  {"name": "Alice", "email": "alice@example.com"},
  {"name": "Bob", "email": "bob@example.com"},
  {"name": "Charlie", "email": "charlie@example.com"}
]' | monk data create users
```
```json
[{"id":"123","name":"Alice","email":"alice@example.com"},{"id":"456","name":"Bob","email":"bob@example.com"},{"id":"789","name":"Charlie","email":"charlie@example.com"}]
```

#### **Update Records**
```bash
monk data update <schema> [id]
```

**Update by ID Parameter:**
```bash
echo '{"name": "Alice Smith", "phone": "+1234567890"}' | monk data update users 123
```

**Update with ID in JSON:**
```bash
echo '{"id": "123", "name": "Alice Johnson", "status": "active"}' | monk data update users
```

**Bulk Updates:**
```bash
echo '[
  {"id": "123", "status": "active"},
  {"id": "456", "status": "inactive"}
]' | monk data update users
```

#### **Delete Records**
```bash
monk data delete <schema> [id]
```

**Delete by ID:**
```bash
monk data delete users 123
```

**Delete with JSON (includes confirmation):**
```bash
echo '{"id": "123"}' | monk data delete users
```

**Bulk Delete:**
```bash
echo '[{"id": "123"}, {"id": "456"}]' | monk data delete users
```

### **Data Import/Export**

#### **Export to Files**
```bash
monk data export <schema> <directory>
```

**Examples:**
```bash
# Export all users to individual JSON files
monk data export users ./backups/users/

# Creates files: ./backups/users/123.json, ./backups/users/456.json, etc.
```

#### **Import from Files**
```bash
monk data import <schema> <directory>
```

**Examples:**
```bash
# Import all JSON files from directory
monk data import users ./migration/users/

# Bulk imports all *.json files in the directory
```

## Input/Output Behavior

### **Smart Array/Object Handling**

Data commands automatically detect input type and handle accordingly:

| Input Type | API Endpoint | Output Type |
|------------|--------------|-------------|
| **Single Object** | `POST /api/data/schema` (wrapped in array) | **Single Object** (unwrapped) |
| **Array** | `POST /api/data/schema` | **Array** |
| **Object with ID** | `PUT /api/data/schema/:id` | **Single Object** |

### **ID Extraction**
- **ID Parameter**: `monk data update users 123` - uses provided ID
- **ID in JSON**: `{"id": "123", "name": "Alice"}` - extracts ID from object
- **Array Operations**: Each object processed with its own ID

## Format Restrictions

Data commands **only support JSON format**:

```bash
# ✅ Correct usage (default JSON)
monk data select users
echo '{"name": "Alice"}' | monk data create users

# ❌ Invalid format flags
monk --text data select users
# Error: The --text option is not supported for data operations
# Data operations require JSON format for structured data handling

monk --text data create users  
# Error: The --text option is not supported for data operations
# Data operations require JSON format for structured data handling
```

**Rationale**: Data operations work with **variable schemas** and **structured records** where JSON is the natural format for machine processing, automation, and API consistency.

## Advanced Features

### **Query Parameters**
```bash
# Pagination
echo '{"limit": 50, "offset": 100}' | monk data select users

# Sorting  
echo '{"order": "created_at desc"}' | monk data select users
echo '{"order": "name asc, email desc"}' | monk data select users

# Combined
echo '{"limit": 20, "order": "name asc", "offset": 40}' | monk data select users
```

### **Complex Queries (Auto-Redirect)**
When JSON input contains a `where` clause, data select automatically redirects to the `find` command:

```bash
echo '{"where": {"status": "active"}, "limit": 10}' | monk data select users
# → Automatically becomes: echo '{"where": {...}}' | monk find users
```

### **Error Handling**
```bash
# Schema validation
echo '{"invalid_field": "value"}' | monk data create users
# Error: Field 'invalid_field' not allowed by schema

# Required field missing
echo '{"name": "Alice"}' | monk data create users
# Error: Required field 'email' is missing

# ID not found
echo '{"name": "Updated"}' | monk data update users 999
# Error: Record with ID '999' not found
```

## Integration Workflow

Typical data workflow with other monk commands:

```bash
# 1. Set up environment
monk server use local
monk tenant use my-app
monk auth login my-app admin

# 2. Define schema (if not exists)
cat user-schema.yaml | monk meta create schema

# 3. Work with data
echo '{"name": "Alice", "email": "alice@example.com"}' | monk data create users
monk data select users
echo '{"id": "123", "status": "verified"}' | monk data update users

# 4. Export for backup
monk data export users ./backups/
```

## Performance Considerations

- **Bulk Operations**: Use arrays for multiple records in single request
- **Pagination**: Use limit/offset for large datasets
- **Specific Selection**: Use ID parameter for single record retrieval
- **Complex Queries**: Use `find` command with Filter DSL for advanced searches

Data commands provide efficient, type-safe record operations while maintaining consistency with the underlying API and schema definitions.