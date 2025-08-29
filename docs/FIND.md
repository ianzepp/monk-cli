# Find Command Documentation

## Overview

The `monk find` command provides **advanced search capabilities** using the enterprise Filter DSL for complex queries, nested conditions, and sophisticated data filtering across dynamic schemas.

**Format Note**: Find command works exclusively with **JSON format** for structured query input and result output. The `--text` flag is not supported as advanced search operations require structured data handling.

## Command Structure

```bash
monk find <schema> [--head|--tail] < query.json
```

## Query Input Format

Find command expects **JSON query objects** via stdin with Filter DSL syntax:

### **Basic Query Structure**
```json
{
  "where": { /* filter conditions */ },
  "limit": 50,
  "offset": 0, 
  "order": "field_name asc|desc"
}
```

## Filter DSL Reference

### **Comparison Operators**

#### **Equality Operations**
```bash
# Exact match
echo '{"where": {"status": "active"}}' | monk find users

# Not equal
echo '{"where": {"status": {"$ne": "deleted"}}}' | monk find users

# Multiple conditions
echo '{"where": {"status": "active", "role": "admin"}}' | monk find users
```

#### **Numeric Comparisons**
```bash
# Greater than
echo '{"where": {"age": {"$gt": 25}}}' | monk find users

# Less than or equal
echo '{"where": {"score": {"$lte": 100}}}' | monk find users

# Range queries
echo '{"where": {"price": {"$gte": 10, "$lt": 50}}}' | monk find products

# Between operator
echo '{"where": {"age": {"$between": [18, 65]}}}' | monk find users
```

### **Array Operations**

#### **Membership Tests**
```bash
# Value in array
echo '{"where": {"category": {"$in": ["electronics", "computers"]}}}' | monk find products

# Value not in array  
echo '{"where": {"status": {"$nin": ["deleted", "archived"]}}}' | monk find users

# Array contains value
echo '{"where": {"tags": {"$any": "urgent"}}}' | monk find tasks

# Array does not contain value
echo '{"where": {"tags": {"$nany": "spam"}}}' | monk find messages
```

### **Pattern Matching**

#### **String Patterns**
```bash
# Case-sensitive like
echo '{"where": {"name": {"$like": "John*"}}}' | monk find users

# Case-insensitive like
echo '{"where": {"email": {"$ilike": "*@company.com"}}}' | monk find users

# Regular expressions
echo '{"where": {"phone": {"$regex": "^\\+1"}}}' | monk find users
```

### **Logical Operations**

#### **Boolean Logic**
```bash
# AND conditions
echo '{"where": {"$and": [{"status": "active"}, {"role": "admin"}]}}' | monk find users

# OR conditions  
echo '{"where": {"$or": [{"priority": "high"}, {"due_date": {"$lt": "2025-08-30"}}]}}' | monk find tasks

# NOT conditions
echo '{"where": {"$not": {"status": "deleted"}}}' | monk find users

# Complex nested logic
echo '{
  "where": {
    "$and": [
      {"status": "active"},
      {
        "$or": [
          {"role": "admin"},
          {"department": "Engineering"}
        ]
      }
    ]
  }
}' | monk find users
```

## Query Examples

### **User Management Queries**
```bash
# Find active administrators
echo '{"where": {"status": "active", "role": "admin"}}' | monk find users

# Find users by email domain
echo '{"where": {"email": {"$ilike": "*@company.com"}}}' | monk find users

# Find recent users
echo '{"where": {"created_at": {"$gte": "2025-08-01"}}}' | monk find users

# Find users with multiple roles
echo '{"where": {"roles": {"$any": ["admin", "moderator"]}}}' | monk find users
```

### **Product Catalog Queries**
```bash
# Products in price range
echo '{"where": {"price": {"$between": [10.00, 100.00]}}}' | monk find products

# Available products with tags
echo '{"where": {"$and": [{"status": "available"}, {"tags": {"$any": "featured"}}]}}' | monk find products

# Products needing restock
echo '{"where": {"inventory": {"$lte": 5}, "status": "active"}}' | monk find products
```

### **Analytics and Reporting**
```bash
# High-value orders this month
echo '{
  "where": {
    "$and": [
      {"total": {"$gte": 1000}},
      {"created_at": {"$gte": "2025-08-01"}},
      {"status": "completed"}
    ]
  },
  "order": "total desc",
  "limit": 100
}' | monk find orders

# Users without recent activity
echo '{
  "where": {
    "$or": [
      {"last_login": {"$lt": "2025-07-01"}},
      {"last_login": null}
    ]
  },
  "order": "created_at asc"
}' | monk find users
```

## Result Processing

### **Pagination and Limiting**
```bash
# First 10 results
echo '{"where": {"status": "active"}, "limit": 10}' | monk find users

# Pagination
echo '{"where": {"status": "active"}, "limit": 10, "offset": 20}' | monk find users

# Get only first result
echo '{"where": {"email": "admin@company.com"}}' | monk find users --head

# Get only last result  
echo '{"where": {"status": "active"}, "order": "created_at asc"}' | monk find users --tail
```

### **Sorting Results**
```bash
# Single field sort
echo '{"where": {"status": "active"}, "order": "name asc"}' | monk find users

# Multiple field sort
echo '{"where": {"status": "active"}, "order": "department asc, name asc"}' | monk find users

# Descending order
echo '{"where": {"status": "published"}, "order": "created_at desc"}' | monk find articles
```

## Response Format

Find command returns **compact JSON arrays**:

```json
[
  {
    "id": "123",
    "name": "Alice Smith",
    "email": "alice@company.com", 
    "status": "active",
    "created_at": "2025-08-15T10:30:00Z"
  },
  {
    "id": "456", 
    "name": "Bob Jones",
    "email": "bob@company.com",
    "status": "active", 
    "created_at": "2025-08-20T14:15:00Z"
  }
]
```

**Perfect for piping to other tools:**
```bash
# Count results
echo '{"where": {"status": "active"}}' | monk find users | jq 'length'

# Extract specific fields
echo '{"where": {"role": "admin"}}' | monk find users | jq -r '.[].email'

# Process results
echo '{"where": {"status": "pending"}}' | monk find orders | jq '.[] | select(.total > 100)'
```

## Integration with Data Commands

### **Automatic Redirection**
Data select automatically redirects complex queries to find:

```bash
# This data command...
echo '{"where": {"status": "active"}, "limit": 10}' | monk data select users

# ...automatically becomes:
echo '{"where": {"status": "active"}, "limit": 10}' | monk find users
```

### **Query Building Workflow**
```bash
# 1. Start with simple data selection
monk data select users

# 2. Add filtering for specific needs
echo '{"limit": 10}' | monk data select users

# 3. Use find for complex queries
echo '{"where": {"$and": [...]}}' | monk find users
```

## Performance Optimization

### **Index-Aware Queries**
```bash
# Good: Query on indexed fields
echo '{"where": {"id": "123"}}' | monk find users
echo '{"where": {"email": "user@example.com"}}' | monk find users

# Consider: May be slower on non-indexed fields
echo '{"where": {"description": {"$like": "*text*"}}}' | monk find articles
```

### **Limit Large Result Sets**
```bash
# Always use limits for potentially large results
echo '{"where": {"status": "active"}, "limit": 100}' | monk find users

# Use pagination for processing large datasets
for offset in 0 100 200 300; do
    echo "{\"limit\": 100, \"offset\": $offset}" | monk find users | jq '.[]'
done
```

## Error Handling

### **Invalid Filter DSL**
```bash
echo '{"where": {"field": {"$invalid_op": "value"}}}' | monk find users
```
```json
{"success":false,"error":"Invalid filter operator '$invalid_op'","supported_operators":["$eq","$ne","$gt","$gte","$lt","$lte","$in","$nin","$like","$ilike","$any","$nany","$between"]}
```

### **Schema Validation**
```bash
echo '{"where": {"nonexistent_field": "value"}}' | monk find users
```
```json
{"success":false,"error":"Field 'nonexistent_field' not found in schema 'users'"}
```

### **Malformed Queries**
```bash
echo '{"invalid": "json"}' | monk find users
```
```json
{"success":false,"error":"Query must contain 'where' field for filtering"}
```

## Format Restrictions

Find command **only supports JSON format**:

```bash
# ✅ Correct usage
echo '{"where": {...}}' | monk find users

# ❌ Invalid format flags
monk --text find users  
# Error: The --text option is not supported for find operations
# Find operations require JSON format for structured query processing
```

**Rationale**: Advanced search requires **structured filter expressions** that are inherently JSON-formatted for complex logical operations and API consistency.

## Advanced Query Patterns

### **Date Range Queries**
```bash
# Records from last week
last_week=$(date -d "7 days ago" -u +"%Y-%m-%dT%H:%M:%SZ")
echo "{\"where\": {\"created_at\": {\"\$gte\": \"$last_week\"}}}" | monk find orders

# Monthly reports
echo '{
  "where": {
    "$and": [
      {"created_at": {"$gte": "2025-08-01T00:00:00Z"}},
      {"created_at": {"$lt": "2025-09-01T00:00:00Z"}}
    ]
  }
}' | monk find sales
```

### **Nested Object Queries**
```bash
# Query nested properties
echo '{"where": {"metadata.category": "electronics"}}' | monk find products

# Complex nested conditions
echo '{
  "where": {
    "$and": [
      {"profile.settings.notifications": true},
      {"profile.preferences.theme": "dark"}
    ]
  }
}' | monk find users
```

### **Aggregation Simulation**
```bash
# Count by status (client-side)
echo '{"where": {}}' | monk find users | jq 'group_by(.status) | map({status: .[0].status, count: length})'

# Sum by field
echo '{"where": {"status": "completed"}}' | monk find orders | jq 'map(.total) | add'
```

Find command provides **enterprise-grade search capabilities** with sophisticated filtering for complex data analysis and retrieval operations.