# Data CRUD Operations

Learn how to create, read, update, and delete records in your Monk API tenant using monk CLI.

## Prerequisites
- Monk CLI configured and authenticated
- Tenant selected and schemas defined
- Basic understanding of your data structure

## Data Operations Overview

Monk CLI provides full CRUD (Create, Read, Update, Delete) operations for dynamic schemas:

- **Create**: Add new records
- **Read/Select**: Retrieve existing records
- **Update**: Modify existing records
- **Delete**: Remove records

All data operations work with JSON and support flexible querying.

## Basic CRUD Examples

### Create Records

#### Create a Single User
```bash
monk data create users << 'EOF'
{
  "name": "John Doe",
  "email": "john@example.com",
  "role": "admin",
  "created_at": "2024-12-01T10:00:00Z"
}
EOF
```

#### Create Multiple Records
```bash
monk data create users << 'EOF'
[
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
]
EOF
```

### Read/Select Records

#### Get All Records
```bash
monk data select users
```

#### Get Specific Record by ID
```bash
monk data select users user-123
```

#### Query with Filters
```bash
# Get users with specific role
monk data select users --filter '{"role": "admin"}'

# Get users created after a date
monk data select users --filter '{"created_at": {"$gt": "2024-01-01"}}'

# Complex queries
monk data select users --filter '{"$and": [{"role": "user"}, {"active": true}]}'
```

### Update Records

#### Update by ID
```bash
monk data update users user-123 << 'EOF'
{
  "name": "John Smith",
  "email": "johnsmith@example.com",
  "last_login": "2024-12-15T14:30:00Z"
}
EOF
```

#### Update Multiple Records
```bash
monk data update users --filter '{"role": "user"}' << 'EOF'
{
  "status": "active",
  "updated_at": "2024-12-15T15:00:00Z"
}
EOF
```

### Delete Records

#### Delete by ID
```bash
monk data delete users user-123
```

#### Delete with Filters
```bash
# Delete inactive users
monk data delete users --filter '{"active": false}'

# Delete old records
monk data delete logs --filter '{"created_at": {"$lt": "2024-01-01"}}'
```

## Advanced Data Operations

### Working with Nested Data
```bash
# Create record with nested objects
monk data create products << 'EOF'
{
  "name": "Wireless Headphones",
  "price": 199.99,
  "category": "electronics",
  "specs": {
    "battery_life": "30 hours",
    "connectivity": "Bluetooth 5.0",
    "weight": "250g"
  },
  "reviews": [
    {"user": "user-1", "rating": 5, "comment": "Great sound!"},
    {"user": "user-2", "rating": 4, "comment": "Good value"}
  ]
}
EOF

# Query nested fields
monk data select products --filter '{"specs.battery_life": "30 hours"}'
monk data select products --filter '{"reviews.0.rating": {"$gte": 4}}'
```

### Array Operations
```bash
# Add to array
monk data update products product-123 << 'EOF'
{
  "reviews": [
    {"user": "user-3", "rating": 5, "comment": "Excellent!"}
  ]
}
EOF

# Query array elements
monk data select users --filter '{"tags": {"$in": ["premium", "vip"]}}'
```

## Data Import/Export

### Export Data
```bash
# Export all users to JSON file
monk data export users ./backup/users.json

# Export filtered data
monk data export users ./backup/active-users.json --filter '{"active": true}'
```

### Import Data
```bash
# Import from JSON file
monk data import users ./backup/users.json

# Import to different tenant
monk tenant use production
monk data import users ./backup/users.json
```

## Best Practices

### Data Validation
```bash
# Always check your data before operations
monk describe select users  # Check schema
monk data select users | head -5  # Preview existing data
```

### Batch Operations
```bash
# Use bulk operations for large datasets
monk bulk submit users-import --file large-dataset.json
monk bulk status users-import
monk bulk result users-import
```

### Error Handling
```bash
# Check for errors in responses
monk data select users 2>&1 | grep -i error

# Validate JSON before sending
echo '{"name": "Test"}' | jq . && monk data create users
```

## Common Patterns

### User Management
```bash
# Create user
monk data create users << 'EOF'
{"name": "Alice", "email": "alice@company.com", "role": "user", "active": true}
EOF

# Update user profile
monk data update users $(monk data select users --filter '{"email": "alice@company.com"}' | jq -r '.[0].id') << 'EOF'
{"department": "engineering", "last_login": "2024-12-15T09:00:00Z"}
EOF

# Deactivate user
monk data update users --filter '{"email": "alice@company.com"}' << 'EOF'
{"active": false, "deactivated_at": "2024-12-15T10:00:00Z"}
EOF
```

### Content Management
```bash
# Create blog post
monk data create posts << 'EOF'
{
  "title": "Getting Started with Monk CLI",
  "content": "Monk CLI is a powerful tool...",
  "author": "admin",
  "tags": ["tutorial", "cli", "monk"],
  "published": true,
  "published_at": "2024-12-15T12:00:00Z"
}
EOF

# Add comment
monk data update posts post-123 << 'EOF'
{
  "comments": [
    {
      "user": "reader1",
      "comment": "Great tutorial!",
      "created_at": "2024-12-15T13:00:00Z"
    }
  ]
}
EOF
```

## Next Steps
- `monk examples schema-creation` - Learn about defining data schemas
- `monk examples advanced-search` - Master complex queries
- `monk examples bulk-operations` - Handle large-scale data operations</content>
<parameter name="filePath">/Users/ianzepp/Workspaces/monk-cli/examples/data-crud.md