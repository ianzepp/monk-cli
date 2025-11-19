# Find and Filter: Querying Your Data

Learn how to search and filter data using both simple filters with `monk data list` and advanced queries with `monk find`.

## Prerequisites
- Monk CLI configured and authenticated
- Schemas with data already created
- Basic understanding of JSON

## Overview

Monk CLI provides two ways to query your data:

1. **`monk data list <schema> --filter <json>`** - Simple filters for basic queries
2. **`monk find <schema>`** - Advanced queries with complex filtering, sorting, and pagination

Choose the right tool for your needs:
- Use `data list --filter` for simple queries (limit, offset, order)
- Use `find` for complex queries (boolean logic, nested conditions, array operations)

## Simple Filtering with `data list`

### Basic Usage

List all records without filters:
```bash
monk data list users
```

### Pagination

Limit the number of results:
```bash
monk data list users --filter '{"limit": 10}'
```

Paginate through results:
```bash
# First page
monk data list users --filter '{"limit": 10, "offset": 0}'

# Second page
monk data list users --filter '{"limit": 10, "offset": 10}'

# Third page
monk data list users --filter '{"limit": 10, "offset": 20}'
```

### Sorting

Sort by a single field:
```bash
# Sort by name ascending
monk data list users --filter '{"order": "name asc"}'

# Sort by created_at descending (newest first)
monk data list users --filter '{"order": "created_at desc"}'
```

Sort by multiple fields:
```bash
monk data list users --filter '{"order": "role asc, name asc"}'
```

### Combining Options

```bash
# Get 20 users, sorted by creation date, skip first 40
monk data list users --filter '{
  "limit": 20,
  "offset": 40,
  "order": "created_at desc"
}'
```

## Advanced Filtering with `find`

The `find` command accepts complex filter criteria via JSON input from stdin.

### Basic Filter Structure

```bash
echo '{
  "where": {
    // Your filter conditions here
  },
  "limit": 100,
  "offset": 0,
  "order": ["created_at desc"]
}' | monk find users
```

### Exact Match Filters

```bash
# Find user by exact email
echo '{
  "where": {
    "email": "john@example.com"
  }
}' | monk find users

# Find all active admins
echo '{
  "where": {
    "role": "admin",
    "active": true
  }
}' | monk find users
```

### Comparison Operators

```bash
# Greater than or equal
echo '{
  "where": {
    "age": {"$gte": 18}
  }
}' | monk find users

# Less than
echo '{
  "where": {
    "age": {"$lt": 65}
  }
}' | monk find users

# Between (range)
echo '{
  "where": {
    "salary": {"$between": [50000, 100000]}
  }
}' | monk find employees

# Not equal
echo '{
  "where": {
    "status": {"$ne": "deleted"}
  }
}' | monk find users
```

### IN Operator (Multiple Values)

```bash
# Find users with specific roles
echo '{
  "where": {
    "role": {"$in": ["admin", "moderator", "editor"]}
  }
}' | monk find users

# Find products in specific categories
echo '{
  "where": {
    "category": {"$in": ["electronics", "computers"]}
  }
}' | monk find products
```

### Pattern Matching (LIKE)

```bash
# Find emails from specific domain
echo '{
  "where": {
    "email": {"$like": "%@company.com"}
  }
}' | monk find users

# Find names starting with 'John'
echo '{
  "where": {
    "name": {"$like": "John%"}
  }
}' | monk find users

# Find names containing 'Smith'
echo '{
  "where": {
    "name": {"$like": "%Smith%"}
  }
}' | monk find users
```

### Logical AND Operator

Combine multiple conditions (all must be true):

```bash
# Find senior engineers
echo '{
  "where": {
    "$and": [
      {"department": "engineering"},
      {"level": "senior"},
      {"active": true}
    ]
  }
}' | monk find employees

# Find products in stock within price range
echo '{
  "where": {
    "$and": [
      {"in_stock": true},
      {"price": {"$gte": 100}},
      {"price": {"$lte": 500}}
    ]
  }
}' | monk find products
```

**Note:** The `$or` and `$not` operators currently have implementation issues. Use `$and` for reliable results.

### Array Operations

```bash
# Check if user has specific access (ACL)
echo '{
  "where": {
    "access_read": {"$any": ["user-123"]}
  }
}' | monk find documents

# Find items with all specified tags
echo '{
  "where": {
    "tags": {"$all": ["urgent", "review"]}
  }
}' | monk find tasks

# Find arrays of specific size
echo '{
  "where": {
    "permissions": {"$size": {"$gte": 3}}
  }
}' | monk find users
```

### Field Selection (Projection)

Return only specific fields:

```bash
# Get only name and email
echo '{
  "select": ["name", "email"],
  "where": {
    "active": true
  }
}' | monk find users

# Get only relevant product info
echo '{
  "select": ["name", "price", "in_stock"],
  "where": {
    "category": "electronics"
  }
}' | monk find products
```

### Sorting and Pagination

```bash
# Get top 10 highest-paid employees
echo '{
  "where": {
    "department": "engineering"
  },
  "order": ["salary desc"],
  "limit": 10
}' | monk find employees

# Get page 3 of results (20 per page)
echo '{
  "where": {
    "active": true
  },
  "order": ["created_at desc"],
  "limit": 20,
  "offset": 40
}' | monk find users
```

## Practical Examples

### Example 1: User Management

```bash
# Find all inactive users
echo '{
  "where": {
    "active": false
  },
  "select": ["name", "email", "last_login"]
}' | monk find users

# Find users who haven't logged in recently
echo '{
  "where": {
    "last_login": {"$lt": "2024-01-01T00:00:00Z"}
  }
}' | monk find users

# Find admins in engineering department
echo '{
  "where": {
    "$and": [
      {"role": "admin"},
      {"department": "engineering"}
    ]
  }
}' | monk find users
```

### Example 2: E-commerce Product Search

```bash
# Find affordable electronics in stock
echo '{
  "where": {
    "$and": [
      {"category": "electronics"},
      {"price": {"$lte": 200}},
      {"in_stock": true}
    ]
  },
  "order": ["price asc"],
  "limit": 20
}' | monk find products

# Find premium products
echo '{
  "where": {
    "tags": {"$any": ["premium"]}
  },
  "order": ["price desc"]
}' | monk find products
```

### Example 3: Content Management

```bash
# Find published posts by specific author
echo '{
  "where": {
    "$and": [
      {"author": "john-doe"},
      {"status": "published"}
    ]
  },
  "order": ["published_at desc"],
  "limit": 10
}' | monk find posts

# Find posts with specific tags
echo '{
  "where": {
    "tags": {"$all": ["tutorial", "beginner"]}
  }
}' | monk find posts
```

### Example 4: Analytics and Reporting

```bash
# Count users by role (get all, process with jq)
echo '{
  "select": ["role"],
  "where": {}
}' | monk find users | jq '[.[] | .role] | group_by(.) | map({role: .[0], count: length})'

# Get summary statistics
echo '{
  "select": ["salary", "department"]
}' | monk find employees | jq 'group_by(.department) | map({
  department: .[0].department,
  avg_salary: ([.[].salary] | add / length),
  count: length
})'
```

## When to Use Each Method

### Use `monk data list --filter` when:
- You need simple pagination (limit/offset)
- You only need sorting (order)
- No complex filtering is required
- Quick queries for all records

### Use `monk find` when:
- You need complex WHERE conditions
- You want to filter by specific field values
- You need comparison operators ($gte, $lt, $between, etc.)
- You want pattern matching ($like)
- You need array operations ($any, $all, $size)
- You need field selection (projection)
- You're building search features

## Tips and Best Practices

### Use Field Selection for Performance

Only request fields you need:
```bash
echo '{
  "select": ["id", "name", "email"],
  "where": {"active": true}
}' | monk find users
```

### Combine with jq for Processing

```bash
# Get just the IDs
echo '{
  "where": {"role": "admin"}
}' | monk find users | jq -r '.[].id'

# Count results
echo '{
  "where": {"active": true}
}' | monk find users | jq 'length'

# Extract specific field
echo '{
  "where": {"department": "sales"}
}' | monk find users | jq -r '.[].email'
```

### Save Complex Queries

```bash
# Save query to file
cat > find-inactive-users.json << 'EOF'
{
  "where": {
    "$and": [
      {"active": false},
      {"last_login": {"$lt": "2024-01-01T00:00:00Z"}}
    ]
  },
  "select": ["name", "email", "last_login"],
  "order": ["last_login desc"]
}
EOF

# Use saved query
cat find-inactive-users.json | monk find users
```

### Test Queries Incrementally

Start simple and add complexity:
```bash
# Step 1: Basic filter
echo '{"where": {"role": "admin"}}' | monk find users

# Step 2: Add condition
echo '{"where": {"$and": [{"role": "admin"}, {"active": true}]}}' | monk find users

# Step 3: Add sorting
echo '{
  "where": {"$and": [{"role": "admin"}, {"active": true}]},
  "order": ["name asc"]
}' | monk find users

# Step 4: Add field selection
echo '{
  "select": ["name", "email"],
  "where": {"$and": [{"role": "admin"}, {"active": true}]},
  "order": ["name asc"]
}' | monk find users
```

## Troubleshooting

### Empty Results

```bash
# Check if data exists
monk data list users

# Simplify query
echo '{"where": {}}' | monk find users

# Check one condition at a time
```

### Invalid Filter Syntax

```bash
# Validate JSON first
echo '{"where": {"name": "test"}}' | jq .

# Then use in query
echo '{"where": {"name": "test"}}' | jq . | monk find users
```

### Performance Issues

- Use field selection to limit data transfer
- Add pagination (limit/offset)
- Create appropriate database indexes (contact your DBA)
- Avoid overly complex nested queries

## Next Steps

- `monk examples describe-and-data` - Learn about schemas and data management
- `monk examples reading-api-docs` - Read full API documentation
- `monk docs find` - Complete Find API reference

## Related Commands

```bash
monk data list <schema>          # List all records
monk data get <schema> <id>      # Get specific record
monk describe get <schema>       # View schema definition
monk describe list               # List all schemas
```

Master filtering and you'll be able to find exactly the data you need!
