# Monk CLI

## Executive Summary

**PaaS Management CLI** - Comprehensive command-line interface for Monk API built with Bashly, providing complete remote API management, tenant administration, and development workflow automation for PaaS backend operations.

### Project Overview
- **Language**: Shell scripting with Bashly CLI framework
- **Purpose**: Complete command-line interface for Monk API PaaS platform management
- **Architecture**: Modular command-based architecture with 50+ individual command implementations
- **Integration**: Direct HTTP API integration with Monk API backend services
- **Distribution**: Compiled binary for easy installation and deployment

### Key Features
- **Multi-Tenant Filesystem Interface**: Explore API data across tenants using familiar unix commands (ls, cat, rm, stat)
- **Cross-Tenant Operations**: Path-based and flag-based tenant routing for multi-environment workflows
- **Complete API Coverage**: Full command-line access to all Monk API functionality
- **Flexible Data Operations**: Smart input detection with array/object handling and unified select command
- **Bulk Operations**: Batch processing with immediate execution and planned async capabilities
- **Multi-Server Management**: Clean server registry with health monitoring and environment switching
- **Advanced Authentication**: JWT management with external token import and expiration tracking
- **Tenant Management**: Create, configure, and manage multi-tenant environments  
- **Schema Management**: YAML-based schema operations with automatic DDL generation
- **Enterprise Search**: Advanced filtering with Filter DSL and intelligent query routing

### Technical Architecture
- **CLI Framework** (50+ command implementations):
  - **Bashly Framework**: Modern CLI framework for organized shell script development
  - **Modular Commands**: Individual shell scripts for each CLI operation
  - **Shared Libraries**: Common functionality in `src/lib/` for code reuse
  - **Clean Config Separation**: Domain-separated configuration (server/auth/context)
- **Smart Input Processing**: Automatic array/object detection and API endpoint routing
- **Build System**: Automated compilation to single distributable binary
- **Installation**: User and system-wide installation support

### Command Categories

#### **Setup & Configuration**
- `monk init` - Initialize CLI configuration with clean domain separation
- `monk server add/list/use/current/ping` - Multi-server infrastructure management
- `monk tenant create/delete/list/use/init` - Multi-tenant environment administration

#### **Authentication & Authorization**  
- `monk auth login/logout` - Standard JWT authentication flows
- `monk auth import` - Import JWT tokens from external auth systems (OAuth, SSO)
- `monk auth token/info/status` - Token inspection and context information
- `monk auth expires/expired` - Token expiration checking and validation
- `monk auth ping` - Authenticated API health checks

#### **Data Operations**
- `monk data select` - Unified selection with intelligent query routing (replaces list/get)
- `monk data create/update/delete` - Flexible CRUD with smart input detection
- `monk data export/import` - Directory-based JSON file operations

#### **Advanced Operations**
- `monk bulk raw` - Immediate bulk operations across multiple schemas  
- `monk find` - Enterprise Filter DSL with complex query support
- `monk meta select/create/update/delete` - YAML-based schema management

#### **Multi-Tenant Filesystem Interface**
- `monk fs ls` - Browse schemas and records like directories with cross-tenant support
- `monk fs cat` - Display record content and individual field values across tenants
- `monk fs rm` - Safe deletion operations with soft delete defaults
- `monk fs stat` - Rich metadata and schema introspection with tenant context
- **Path-based routing**: `/tenant/tenant-a/data/users/` for intuitive multi-tenant access
- **Flag-based targeting**: `--tenant tenant-a` for explicit tenant specification

#### **System Operations**
- `monk test git/diff` - Git-based test environment management

### CLI Design Patterns
- **Logical Command Flow**: init → server → tenant → auth → data workflow
- **Multi-Tenant Operations**: Path-based (`/tenant/name/data/`) and flag-based (`--tenant name`) tenant routing
- **Smart Input Detection**: Automatic array/object routing to appropriate API endpoints
- **Flexible Parameters**: Optional ID parameters with JSON extraction fallbacks
- **Clean Config Separation**: server.json (infrastructure) + auth.json (sessions) + env.json (context)
- **Consistent Output**: Input format preserved in output (array→array, object→object)
- **Pipe-Safe Design**: Status messages to stderr, data to stdout for clean pipelines
- **External Auth Support**: JWT import from OAuth, SSO, and external authentication systems
- **Cross-Environment Access**: Operate on multiple tenants/servers without manual context switching

### Development Workflow Integration
- **Remote Management**: Complete API management from command line
- **Automation Ready**: Scriptable commands for CI/CD integration
- **Multi-Environment**: Seamless switching between development, staging, production
- **Testing Support**: Built-in connectivity and functionality testing
- **Configuration Management**: Centralized CLI configuration with environment switching

### Installation & Quick Start
- **One-Command Install**: `./install.sh` handles complete installation
- **Binary Distribution**: Compiled binary for easy deployment
- **Quick Start Workflow**:
  ```bash
  monk init                           # Initialize CLI configuration
  monk server add local localhost:9001 # Add server endpoint  
  monk tenant create my-tenant        # Create tenant database
  monk auth login my-tenant admin     # Authenticate
  monk data select users              # Start working with data
  
  # Multi-tenant filesystem exploration
  monk fs ls /data/                   # Browse current tenant
  monk fs ls /tenant/other-tenant/data/ # Browse different tenant
  monk fs cat /data/users/user-123.json # Read complete record
  monk fs cat /data/users/user-123/email # Read specific field
  ```
- **User Installation**: Install to `~/.local/bin` without sudo requirements
- **System Installation**: Optional system-wide installation to `/usr/local/bin`

### Enterprise Features
- **Multi-Tenant Support**: Complete tenant isolation and management
- **Security**: JWT-based authentication with secure token management
- **Environment Management**: Multiple server and environment configuration
- **Audit Capabilities**: Command logging and operation tracking
- **Automation Ready**: Scriptable interface for enterprise automation workflows

### Development Features
- **Bashly Framework**: Modern CLI development with organized shell scripting
- **Modular Architecture**: Individual command implementations for maintainability
- **Live Rebuild**: `bashly generate` for rapid development iteration
- **Comprehensive Help**: Built-in documentation and usage guidance
- **Testing Integration**: CLI testing commands for validation workflows

### Integration Ecosystem
- **Monk API**: Complete integration with Monk API PaaS platform
- **HTTP API Client**: Robust API communication with error handling
- **JSON/YAML Processing**: Structured data handling for API operations
- **Shell Environment**: Native shell integration for automation and scripting

### Use Cases
- **API Administration**: Remote management of Monk API instances
- **Development Workflow**: CLI-driven development and testing processes
- **Automation Scripts**: Scriptable API operations for CI/CD pipelines
- **Multi-Environment Management**: Development, staging, and production environment coordination
- **Tenant Administration**: Multi-tenant SaaS application management

### Archive Value
Excellent reference for:
- **CLI Development Patterns**: Modern command-line interface architecture with Bashly
- **API Client Development**: HTTP API integration patterns in shell scripting
- **Multi-Tenant CLI Design**: Command-line interface for multi-tenant platform management
- **Shell Script Architecture**: Organized, maintainable shell script development
- **Enterprise CLI Tools**: Professional command-line tool development patterns

Essential example of modern CLI development demonstrating comprehensive API management, multi-tenant administration, and professional command-line tool architecture for PaaS platform management.

---

**For installation instructions, quick start guide, and command examples, see [INSTALL.md](INSTALL.md)**