# Basic Setup and First Connection

Get started with monk CLI by initializing configuration and connecting to your first Monk API server.

## Prerequisites
- Monk CLI installed
- Access to a Monk API server (running instance)

## Quick Start Workflow

### 1. Initialize CLI Configuration
```bash
monk init
```
This creates the necessary configuration directories and files.

### 2. Add Your Server
```bash
monk server add dev localhost:3000 --description "Development server"
```
Replace `localhost:3000` with your actual server endpoint.

### 3. Switch to Your Server
```bash
monk server use dev
```

### 4. Create a Tenant
```bash
monk tenant add myproject "My Project"
```

### 5. Switch to Your Tenant
```bash
monk tenant use myproject
```

### 6. Authenticate
```bash
monk auth login myproject admin
```
Enter your admin password when prompted.

### 7. Verify Connection
```bash
monk server ping
monk auth status
```

## What This Sets Up

After running these commands, you'll have:
- ✅ CLI configuration initialized
- ✅ Server connection configured
- ✅ Tenant created and selected
- ✅ Authentication established
- ✅ Ready to work with data and schemas

## Expected Output

```bash
$ monk init
✓ CLI configuration initialized

$ monk server add dev localhost:3000 --description "Development server"
✓ Server 'dev' added successfully

$ monk server use dev
✓ Switched to server 'dev'

$ monk tenant add myproject "My Project"
✓ Tenant 'myproject' added successfully

$ monk tenant use myproject
✓ Switched to tenant 'myproject'

$ monk auth login myproject admin
Password: ********
✓ Authentication successful

$ monk server ping
✓ Server 'dev' is healthy

$ monk auth status
Authenticated as: admin@myproject
Token expires: 2024-12-31 23:59:59
```

## Troubleshooting

### Connection Issues
```bash
# Check if server is running
monk server ping dev

# Get detailed server info
monk server info dev

# Check server health
monk server health dev
```

### Authentication Issues
```bash
# Check auth status
monk auth status

# Clear and re-authenticate
monk auth logout
monk auth login myproject admin
```

## Next Steps
Now that you're connected, try:
- `monk examples tenant-management` - Learn about tenant operations
- `monk examples data-crud` - Start working with data
- `monk examples schema-creation` - Define your data structures</content>
<parameter name="filePath">/Users/ianzepp/Workspaces/monk-cli/examples/basic-setup.md