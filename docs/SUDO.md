# Sudo Commands Documentation

## Overview

The `monk sudo` commands provide **user management operations** that require explicit privilege escalation through short-lived sudo tokens. These commands enable tenant-scoped administrative tasks with enhanced security through time-limited access and audit trails.

**Security Model**: All sudo operations require a valid sudo token obtained from `monk auth sudo`, which expires after 15 minutes.

## Command Structure

```bash
monk sudo users <operation> [arguments] [flags]
```

## Authentication Flow

### 1. Regular Authentication
```bash
# First, authenticate normally with root access
monk auth login my-app admin
```

### 2. Sudo Token Acquisition
```bash
# Request sudo token (15-minute validity)
monk auth sudo --reason "Creating new team member"
```

### 3. Sudo Operations
```bash
# Use sudo commands with the active sudo token
monk sudo users list
monk sudo users create --name "John Doe" --auth "john@example.com" --access "full"
```

## Sudo Token Management

### **Request Sudo Token**
```bash
monk auth sudo [--reason <text>]
```

**Options:**
- `--reason` - Audit trail description (recommended)

**Examples:**
```bash
# With reason (recommended)
monk auth sudo --reason "Adding new team member"

# Without reason
monk auth sudo
```

**Output:**
```
Requesting sudo token with reason: Adding new team member
✓ Sudo token acquired successfully
Elevated from: root
Expires in: 900 seconds (15 minutes)

⚠ Root token expires in 15 minutes

Use 'monk sudo users' commands to perform user management operations
```

**Token Lifecycle:**
- **Duration**: 15 minutes
- **Storage**: Separate from regular JWT tokens
- **Expiration**: Automatic after 15 minutes
- **Re-acquisition**: Run `monk auth sudo` again

## User Management Commands

### **List All Users**

```bash
monk sudo users list
```

**Text Format (Default):**
```
Total users: 3

ID                                   NAME                           AUTH                           ACCESS    
--------------------------------------------------------------------------------
550e8400-e29b-41d4-a716-446655440000 Administrator                 admin@example.com              root      
660e8400-e29b-41d4-a716-446655440001 John Doe                      john@example.com               full      
770e8400-e29b-41d4-a716-446655440002 Jane Smith                    jane@example.com               edit      
```

**JSON Format:**
```bash
monk --json sudo users list
```
```json
{
  "success": true,
  "data": [
    {
      "id": "550e8400-e29b-41d4-a716-446655440000",
      "name": "Administrator",
      "auth": "admin@example.com",
      "access": "root",
      "created_at": "2025-11-13T10:00:00Z",
      "updated_at": "2025-11-13T10:00:00Z"
    }
  ]
}
```

---

### **Create New User**

```bash
monk sudo users create --name <name> --auth <identifier> --access <level>
```

**Required Flags:**
- `--name` - Display name for the user
- `--auth` - Authentication identifier (username/email, must be unique)
- `--access` - Access level: `deny`, `read`, `edit`, `full`, or `root`

**Examples:**
```bash
# Create user with full access
monk sudo users create \
  --name "John Doe" \
  --auth "john@example.com" \
  --access "full"

# Create user with read-only access
monk sudo users create \
  --name "Jane Smith" \
  --auth "jane@example.com" \
  --access "read"

# Create another admin with root access
monk sudo users create \
  --name "Admin User" \
  --auth "admin2@example.com" \
  --access "root"
```

**Output:**
```
Creating user: John Doe (john@example.com) with access level: full
✓ User created successfully
User ID: 660e8400-e29b-41d4-a716-446655440001
Name: John Doe
Auth: john@example.com
Access: full
```

**Access Levels:**
- `deny` - No access
- `read` - Read-only data access
- `edit` - Can modify data
- `full` - Can modify data and manage ACLs on records
- `root` - Can request sudo tokens for user management

---

### **Show User Details**

```bash
monk sudo users show <user-id>
```

**Arguments:**
- `<user-id>` - User UUID

**Examples:**
```bash
monk sudo users show 660e8400-e29b-41d4-a716-446655440001
```

**Output:**
```
Fetching user details for: 660e8400-e29b-41d4-a716-446655440001

✓ User Details

ID:          660e8400-e29b-41d4-a716-446655440001
Name:        John Doe
Auth:        john@example.com
Access:      full
Created:     2025-11-13T10:30:00Z
Updated:     2025-11-13T10:30:00Z
```

---

### **Update User**

```bash
monk sudo users update <user-id> [--name <name>] [--access <level>]
```

**Arguments:**
- `<user-id>` - User UUID

**Optional Flags:**
- `--name` - Update display name
- `--access` - Update access level

**Examples:**
```bash
# Update user's access level
monk sudo users update 660e8400-e29b-41d4-a716-446655440001 --access "root"

# Update user's name
monk sudo users update 660e8400-e29b-41d4-a716-446655440001 --name "John Smith"

# Update both name and access
monk sudo users update 660e8400-e29b-41d4-a716-446655440001 \
  --name "John Smith" \
  --access "full"
```

**Output:**
```
Updating user: 660e8400-e29b-41d4-a716-446655440001
✓ User updated successfully
User ID: 660e8400-e29b-41d4-a716-446655440001
Access: root
```

---

### **Delete User**

```bash
monk sudo users delete <user-id> [--force]
```

**Arguments:**
- `<user-id>` - User UUID

**Options:**
- `--force` - Skip confirmation prompt

**Examples:**
```bash
# Delete with confirmation
monk sudo users delete 660e8400-e29b-41d4-a716-446655440001

# Delete without confirmation
monk sudo users delete 660e8400-e29b-41d4-a716-446655440001 --force
```

**Output (with confirmation):**
```
⚠ This will soft-delete the user: 660e8400-e29b-41d4-a716-446655440001
Are you sure? (y/N): y
Deleting user: 660e8400-e29b-41d4-a716-446655440001
✓ User deleted successfully
User ID: 660e8400-e29b-41d4-a716-446655440001
Trashed at: 2025-11-13T12:00:00Z
```

**Note**: User deletion is a soft delete (sets `trashed_at` timestamp).

---

## Security Features

### **Time-Limited Access**
- Sudo tokens expire after 15 minutes
- Automatic expiration prevents accidental operations
- Must re-acquire token for extended work

### **Audit Trail**
- Optional `--reason` parameter logs intent
- All sudo operations are logged by the server
- Tracks who performed dangerous operations and why

### **Tenant Isolation**
- All operations are tenant-scoped
- Cannot manage users in other tenants
- Maintains multi-tenant security boundaries

### **Explicit Privilege Escalation**
- Even root users must explicitly request sudo
- Separates regular operations from dangerous ones
- Forces conscious decision for user management

## Error Handling

### **No Sudo Token**
```bash
monk sudo users list
# Error: No sudo token found or token expired
# Use 'monk auth sudo' to acquire a sudo token first
```

### **Sudo Token Expired**
```bash
monk sudo users list
# HTTP Error (401) - Unauthorized
# Your sudo token may have expired. Use 'monk auth sudo' to get a new token
```

### **Insufficient Privileges**
```bash
monk auth sudo
# Failed to acquire sudo token
# You must have root access level to use sudo commands
```

### **Duplicate User**
```bash
monk sudo users create --name "John" --auth "john@example.com" --access "full"
# HTTP Error (409)
# {"success":false,"error":"DUPLICATE_AUTH","message":"User with auth 'john@example.com' already exists"}
```

## Common Workflows

### **Add New Team Member**
```bash
# 1. Authenticate as admin
monk auth login my-app admin

# 2. Get sudo token
monk auth sudo --reason "Adding new developer"

# 3. Create user
monk sudo users create \
  --name "Alice Developer" \
  --auth "alice@company.com" \
  --access "edit"

# 4. Verify creation
monk sudo users list
```

### **Promote User to Admin**
```bash
# 1. Get sudo token
monk auth sudo --reason "Promoting user to admin"

# 2. List users to find ID
monk sudo users list

# 3. Update access level
monk sudo users update 660e8400-e29b-41d4-a716-446655440001 --access "root"
```

### **Audit User Access**
```bash
# 1. Get sudo token
monk auth sudo --reason "Auditing user access levels"

# 2. List all users with JSON output
monk --json sudo users list | jq '.data[] | {name: .name, auth: .auth, access: .access}'
```

### **Remove Inactive User**
```bash
# 1. Get sudo token
monk auth sudo --reason "Removing inactive user account"

# 2. Find user to remove
monk sudo users list

# 3. Delete user
monk sudo users delete 660e8400-e29b-41d4-a716-446655440001
```

## Integration with Other Commands

Sudo operations work seamlessly with the rest of monk-cli:

```bash
# After creating a user, they can authenticate
monk auth login my-app john@example.com

# Then access tenant resources
monk data list users
monk describe select users
monk fs ls /data/
```

## Best Practices

1. **Always Provide Reason**: Use `--reason` for audit trails
   ```bash
   monk auth sudo --reason "Creating service account for CI/CD"
   ```

2. **Minimize Sudo Duration**: Request token only when needed
   ```bash
   # Don't request sudo preemptively
   # Request it right before user management tasks
   ```

3. **Verify Before Deletion**: Review user details before deleting
   ```bash
   monk sudo users show <user-id>  # Check first
   monk sudo users delete <user-id>  # Then delete
   ```

4. **Use JSON for Scripts**: Programmatic access with JSON output
   ```bash
   user_id=$(monk --json sudo users list | jq -r '.data[] | select(.auth=="john@example.com") | .id')
   ```

5. **Monitor Token Expiration**: Be prepared to re-acquire
   ```bash
   # If you see "token expired" errors
   monk auth sudo --reason "Continuing user management"
   ```

6. **Separate Tokens**: Don't confuse user JWT with sudo token
   - User JWT: Long-lived (1 hour), for regular operations
   - Sudo token: Short-lived (15 minutes), for user management only

## Sudo vs Regular Auth

| Feature | Regular JWT (`monk auth login`) | Sudo Token (`monk auth sudo`) |
|---------|--------------------------------|------------------------------|
| Duration | 1 hour | 15 minutes |
| Purpose | Data operations | User management |
| Requires | Tenant + Username | Existing root JWT |
| Access Level | As configured in user | Temporary root access |
| Audit Logging | Standard | Enhanced with reason |
| Token Type | Long-lived | Short-lived |

## Related Commands

- `monk auth login` - Authenticate to get user JWT
- `monk auth status` - Check authentication status
- `monk auth logout` - Clear authentication tokens
- `monk config tenant list` - List available tenants (for context)

---

Sudo commands provide **secure, time-limited administrative operations** with explicit privilege escalation and comprehensive audit trails for monk-cli user management.
