# 10-Connection: Basic Server Connection Tests

Tests for basic server connectivity and CLI communication functionality.

**Scope:**
- Server ping functionality
- Server listing and discovery
- Server health monitoring
- Basic CLI command execution
- Error handling for connection issues

**Test Focus:**
- Verify CLI can communicate with configured server
- Test basic server operations (ping, list, health)
- Validate error handling for connection failures
- Ensure proper output formatting

**Test Files:**
- `01-ping-server.test.sh` - Basic server connectivity and ping operations

**Prerequisites:**
- Server must be configured (use `monk server add` if needed)
- Basic authentication may be required for some operations

**Usage:**
```bash
# Run the connection test
./spec/10-connection/01-ping-server.test.sh

# Run with verbose output
CLI_VERBOSE=true ./spec/10-connection/01-ping-server.test.sh
```