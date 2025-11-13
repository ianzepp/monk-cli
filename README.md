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
- **Universal Output Formats**: Global `--text` and `--json` flags with format-optimized command design
- **Multi-Tenant Filesystem Interface**: Explore API data using familiar Unix commands (ls, cat, rm, stat)
- **Cross-Tenant Operations**: Path-based and flag-based tenant routing for multi-environment workflows
- **Complete API Coverage**: Full command-line access to all Monk API functionality
- **Smart Data Operations**: Intelligent array/object handling with compact JSON output
- **Bulk Operations**: Batch processing with immediate execution and enterprise Filter DSL
- **Multi-Server Management**: Clean server registry with health monitoring and context switching
- **Advanced Authentication**: JWT session management with external token import
- **Administrative Operations**: Root tenant management with Unicode support
- **Schema Management**: JSON-based schema operations with automatic DDL generation

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

#### **Infrastructure & Setup**
- `monk init` - Initialize CLI configuration with customizable directory support
- `monk config server` - Multi-server registry, health monitoring, and context switching
- `monk config tenant` - Server-scoped tenant registry management and context selection

#### **Authentication & Security**  
- `monk auth` - JWT authentication workflows with session management and token inspection

#### **Data & Schema Operations**
- `monk data` - CRUD operations with intelligent array/object handling (JSON-exclusive)
- `monk describe` - Schema management with JSON definitions and automatic DDL generation (JSON-exclusive)
- `monk bulk` - Batch processing operations across multiple schemas (JSON-exclusive)
- `monk find` - Advanced search with enterprise Filter DSL (JSON-exclusive)

#### **Administrative Operations**
- `monk root` - Administrative tenant management with Unicode support (localhost development)

#### **Filesystem Interface**
- `monk fs` - Unix-like data exploration with cross-tenant path routing and metadata inspection

#### **Project Management**
- `monk project` - Simplified project creation and management with automatic tenant setup


### Output Format System
- **Universal Flags**: Global `--text` and `--json` flags for consistent output control
- **Format-Optimized Design**: Text for humans, compact JSON for machines, native YAML for schemas
- **Command-Specific Behavior**: Administrative commands support both formats, data commands are JSON-exclusive, describe commands are JSON-exclusive
- **Machine-Readable JSON**: Single-line compact format optimized for automation and parsing
- **Human-Readable Text**: Tables, formatted output, and status indicators for interactive use

## Documentation

### **📚 Command Reference**
Comprehensive command documentation available in the `docs/` directory:

- **[INIT.md](docs/INIT.md)** - Configuration initialization and setup workflows
- **[SERVER.md](docs/SERVER.md)** - Multi-environment server management and health monitoring  
- **[TENANT.md](docs/TENANT.md)** - Tenant registry management and context switching
- **[AUTH.md](docs/AUTH.md)** - JWT authentication, session management, and security
- **[DATA.md](docs/DATA.md)** - CRUD operations with JSON-exclusive design
- **[DESCRIBE.md](docs/DESCRIBE.md)** - Schema management with YAML definitions
- **[BULK.md](docs/BULK.md)** - Batch processing and cross-schema operations
- **[FIND.md](docs/FIND.md)** - Advanced search with enterprise Filter DSL
- **[FS.md](docs/FS.md)** - Unix-like filesystem operations for data exploration
- **[ROOT.md](docs/ROOT.md)** - Administrative tenant management (localhost development)
- **[PROJECT.md](docs/PROJECT.md)** - Simplified project management and workflow

### **🚀 Practical Examples**
Complete, ready-to-run examples in the `examples/` directory:

- **[Exercise Tracker Project](examples/exercise-tracker-project.md)** - Complete project example with schema design, data operations, and realistic workflows
- **[Basic Setup](examples/basic-setup.md)** - Initial configuration and first connection
- **[Server Management](examples/server-management.md)** - Multi-server setup and management
- **[Tenant Management](examples/tenant-management.md)** - Traditional tenant administration
- **[Data CRUD Operations](examples/data-crud.md)** - Basic data manipulation examples

**🎯 Start Here**: The [Exercise Tracker Project](examples/exercise-tracker-project.md) provides the most comprehensive learning experience, demonstrating the complete workflow from project creation to data operations.

Each documentation file includes practical examples, error handling guidance, automation patterns, and integration workflows.

## Installation

### End Users (Simple Installation)

**No development dependencies required** - uses prebuilt binaries:

```bash
# Clone repository
git clone <repository-url>
cd monk-cli

# Install latest version
./install.sh

# OR install specific version
./install.sh 2.2.0

# Verify installation
monk --version
```

**Features:**
- **No bashly required** - Uses prebuilt binaries from `bin/` directory
- **Version selection** - Install latest or specific version
- **User installation** - Installs to `~/.local/bin` (no sudo required)
- **System installation** - Automatic if you have sudo permissions

### Quick Start Workflow

#### **Simplified Project Setup (Recommended)**
```bash
monk init                           # Initialize CLI configuration
monk config server add local localhost:9001 # Add server endpoint  
monk config server use local               # Select server
monk project init "My App" --create-user admin --auto-login  # Create project!
monk data select users              # Start working with data immediately

# Multi-tenant filesystem exploration
monk fs ls /data/                   # Browse current project
monk fs cat /data/users/user-123.json # Read complete record
monk fs cat /data/users/user-123/email # Read specific field
```

#### **Traditional Tenant Setup**
```bash
monk init                           # Initialize CLI configuration
monk config server add local localhost:9001 # Add server endpoint  
monk config tenant add my-tenant "My Tenant" # Register tenant for server
monk config server use local               # Select server
monk config tenant use my-tenant           # Select tenant
monk auth login my-tenant admin     # Authenticate to server+tenant
monk data select users              # Start working with data
```

### Output Format Examples

```bash
# Universal format support for administrative commands
monk config server list                    # Default: human-readable table
monk --json server list             # Compact: {"servers":[...],"current_server":"local"}

# Format-optimized command design  
monk data select users              # Default: compact JSON for data operations
monk describe select users          # Default: native JSON for schema definitions

# Administrative operations with Unicode support
monk root tenant list               # List all tenants (localhost development)
monk --json root tenant create "测试应用 🚀"  # Create tenant with Unicode name
```

## Development Setup

### Local Toolchain Setup

**Required for development** (not end users):

```bash
# Install Ruby and Bashly
gem install bashly

# Clone repository  
git clone <repository-url>
cd monk-cli
```

### Development Scripts

**For developers modifying the CLI:**

```bash
# 1. Rebuild after making changes
./rebuild.sh              # Requires bashly - creates bin/monk

# 2. Test locally
bin/monk --help           # Test development binary

# 3. Create versioned release
./release.sh              # Creates bin/monk-X.Y.Z from bin/monk

# 4. Install locally for testing
./install.sh              # Installs latest (bin/monk)
./install.sh 2.2.0        # Installs specific version

# 5. Commit release
git add bin/monk-2.2.0 && git commit -m "Release v2.2.0"
git tag v2.2.0 && git push --tags
```

### Binary Management

- **`bin/monk`** - Latest development binary (ignored by git)
- **`bin/monk-X.Y.Z`** - Versioned release binaries (committed to git)
- **`rebuild.sh`** - Developer build script (requires bashly)
- **`release.sh`** - Create versioned releases  
- **`install.sh`** - End user installer (no dependencies)

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
- **Rapid Prototyping**: Single-command project setup for quick idea validation

### Archive Value
Excellent reference for:
- **CLI Development Patterns**: Modern command-line interface architecture with Bashly
- **API Client Development**: HTTP API integration patterns in shell scripting
- **Multi-Tenant CLI Design**: Command-line interface for multi-tenant platform management
- **Shell Script Architecture**: Organized, maintainable shell script development
- **Enterprise CLI Tools**: Professional command-line tool development patterns

Essential example of modern CLI development demonstrating comprehensive API management, multi-tenant administration, and professional command-line tool architecture for PaaS platform management.

---

**Complete installation guide and development setup included above. For additional examples, see [INSTALL.md](INSTALL.md)**