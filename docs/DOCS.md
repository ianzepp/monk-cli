# Documentation Commands

## Overview

The `monk docs` commands provide **API documentation viewing** directly from the terminal. These commands fetch live documentation from the connected server's documentation endpoints and display them with enhanced formatting when available.

**Enhanced Display**: Commands automatically use [glow](https://github.com/charmbracelet/glow) for beautiful markdown rendering if installed, otherwise display raw markdown.

## Command Structure

```bash
monk docs <api>
```

## Available Commands

### **Authentication API Documentation**
```bash
monk docs auth
```

Fetches and displays documentation for authentication endpoints including:
- User login and token management
- JWT token refresh flows
- User information retrieval
- Error handling and status codes

**Example:**
```bash
monk docs auth
# Fetching auth API documentation from: local
# [Displays formatted markdown documentation]
```

### **Data API Documentation**
```bash
monk docs data
```

Fetches and displays documentation for data management endpoints including:
- CRUD operations for schema records
- Bulk data operations
- Soft delete and permanent delete functionality
- Query parameters and filtering

**Example:**
```bash
monk docs data
# Fetching data API documentation from: local
# [Displays formatted markdown documentation]
```

## Enhanced Formatting

### **With Glow (Recommended)**
When `glow` is installed, documentation is displayed with:
- **Syntax highlighting** for code blocks
- **Formatted tables** with proper alignment
- **Styled headers** and emphasis
- **Color coding** based on terminal theme

### **Without Glow (Fallback)**
When `glow` is not available, documentation displays as:
- **Raw markdown** text output
- **Readable format** with standard markdown syntax
- **Complete content** with all formatting preserved

## Server Context

Documentation commands use the **current server context**:

```bash
# Set server context
monk server use production

# Fetch docs from production server
monk docs data

# Switch to development
monk server use local

# Fetch docs from development server  
monk docs auth
```

## Prerequisites

1. **Server Selection**: Must have a current server selected via `monk server use <name>`
2. **Server Connectivity**: Target server must be running and accessible
3. **API Availability**: Server must support documentation endpoints (`/docs/auth`, `/docs/data`)

## Error Handling

### **No Server Selected**
```bash
monk docs data
# Error: No current server selected
# Use 'monk server use <name>' to select a server first
```

### **Server Connectivity Issues**
```bash
monk docs auth
# Error: Failed to fetch documentation from server 'staging'
# Ensure server is running and documentation endpoint is available
```

### **Missing Documentation Endpoint**
If the server doesn't support the documentation endpoint, the command will fail with a connection error.

## Installation of Glow (Optional)

For enhanced markdown display, install glow:

```bash
# macOS (Homebrew)
brew install glow

# Linux (various package managers)
# Ubuntu/Debian
sudo apt install glow

# Arch Linux  
pacman -S glow

# From source
go install github.com/charmbracelet/glow@latest
```

## Integration with Other Commands

Documentation commands complement server and API operations:

```bash
# Check available documentation from server info
monk server info

# Read specific API documentation
monk docs data

# Use the API with understanding from docs
monk data select users
```

The documentation commands provide **live, server-specific** API documentation directly in your terminal workflow.