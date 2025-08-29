# Monk CLI Installation Guide

## Quick Start

1. **Install the CLI:**
   ```bash
   git clone https://github.com/ianzepp/monk-cli.git
   cd monk-cli
   ./install.sh
   ```

2. **Initialize configuration:**
   ```bash
   monk init
   ```

3. **Set up your environment:**
   ```bash
   monk server add local localhost:9001 --description "Local development"
   monk server use local
   monk tenant add my-app "My Application"
   monk tenant use my-app
   monk auth login my-app admin
   ```

4. **Start working:**
   ```bash
   monk --help
   monk data select users
   monk --json server list
   ```

## Installation Options

### **End Users (Recommended)**

**No development dependencies required** - uses prebuilt binaries:

```bash
# Clone repository
git clone https://github.com/ianzepp/monk-cli.git
cd monk-cli

# Install latest version
./install.sh

# OR install specific version
./install.sh 2.4.2

# Verify installation
monk --version
```

**What it does:**
- Installs prebuilt binary from `bin/` directory
- No bashly or Ruby dependencies required
- User installation to `~/.local/bin/monk` (no sudo required)
- System installation to `/usr/local/bin/monk` (with sudo permissions)
- Version selection support for specific releases

### **Developer Installation**

**For CLI development and contribution:**

```bash
# Install Ruby and Bashly
gem install bashly

# Clone repository  
git clone https://github.com/ianzepp/monk-cli.git
cd monk-cli

# Build development version
./rebuild.sh

# Test locally
./bin/monk --help

# Install locally
./install.sh
```

## Configuration Setup

### **Default Configuration**

```bash
# Initialize with default directory (~/.config/monk/cli/)
monk init

# Verify configuration
ls ~/.config/monk/cli/
# auth.json  env.json  server.json  tenant.json
```

### **Custom Configuration Directory**

```bash
# Use custom location
export MONK_CLI_CONFIG_DIR="/path/to/custom/config"
monk init

# OR specify path directly
monk init /path/to/custom/config
```

**Use Cases:**
- **Project isolation**: Separate configurations per project
- **CI/CD environments**: Temporary configurations
- **Team environments**: Shared configuration locations

## Environment Setup

### **Single Environment**
```bash
monk init
monk server add local localhost:9001
monk server use local
monk tenant add my-app "My Application"
monk tenant use my-app
monk auth login my-app admin
```

### **Multi-Environment Setup**
```bash
# Development
monk server add dev localhost:9001 --description "Development"
monk tenant add dev-app "Development App"

# Staging  
monk server add staging api.staging.com:443 --description "Staging"
monk tenant add staging-app "Staging App"

# Production
monk server add prod api.company.com:443 --description "Production"
monk tenant add prod-app "Production App"

# Switch between environments
monk server use dev && monk tenant use dev-app
monk server use staging && monk tenant use staging-app
```

## Verification

### **Test Basic Functionality**
```bash
# Check version and help
monk --version
monk --help

# Test configuration
monk server list
monk tenant list
monk auth status

# Test output formats
monk --text server list
monk --json server list
```

### **Test API Connectivity**
```bash
# Health checks
monk server ping
monk server ping-all

# Authentication test
monk auth ping
```

## Troubleshooting

### **Command Not Found**
```bash
monk --version
# bash: monk: command not found
```

**Solution**: Add `~/.local/bin` to your PATH:
```bash
echo 'export PATH="$PATH:$HOME/.local/bin"' >> ~/.bashrc
source ~/.bashrc
```

### **Configuration Issues**
```bash
# Reset configuration
monk init --force

# Check configuration location
echo $MONK_CLI_CONFIG_DIR
ls -la ~/.config/monk/cli/
```

### **Permission Issues**
```bash
# Fix auth.json permissions
chmod 600 ~/.config/monk/cli/auth.json

# Fix directory permissions
chmod 755 ~/.config/monk/cli/
```

### **Build Issues (Developers)**
```bash
# Verify bashly installation
bashly --version

# Clean rebuild
rm -f ./bin/monk
./rebuild.sh

# Check for syntax errors
bashly validate
```

## Version Management

### **Install Specific Version**
```bash
# List available versions
ls bin/monk-*

# Install specific version
./install.sh 2.4.2
./install.sh 2.4.1
```

### **Upgrade to Latest**
```bash
# Pull latest changes
git pull

# Install latest version
./install.sh

# Verify upgrade
monk --version
```

## Dependencies

### **End Users**
- **curl** - HTTP requests (usually pre-installed)
- **jq** - JSON processing (install via package manager)

### **Developers**  
- **Ruby** - For bashly CLI framework
- **bashly** - CLI generator (`gem install bashly`)

### **Optional**
- **yq** - YAML processing (for advanced meta operations)

## Uninstallation

### **Remove Binary**
```bash
# User installation
rm ~/.local/bin/monk

# System installation  
sudo rm /usr/local/bin/monk
```

### **Remove Configuration**
```bash
# Remove default configuration
rm -rf ~/.config/monk/

# Remove custom configuration
rm -rf $MONK_CLI_CONFIG_DIR
```

## Team Setup

### **Shared Server Configuration**
```bash
# Export server config for team
monk --json server list > team-servers.json

# Team members import
jq -r '.servers[] | "monk server add \(.name) \(.endpoint) --description \"\(.description)\""' team-servers.json | bash
```

### **Project Configuration Template**
```bash
#!/bin/bash
# setup-team-environment.sh

monk init
monk server add local localhost:9001 --description "Local development"
monk server add staging api.staging.company.com:443 --description "Staging"
monk tenant add main-app "Main Application" 
monk tenant add test-app "Test Application"
monk server use local
monk tenant use main-app

echo "✅ Team environment configured"
echo "Next: monk auth login main-app <your-username>"
```

## Security Considerations

- **Configuration Security**: Auth tokens stored with 600 permissions
- **Network Security**: HTTPS recommended for production servers
- **Token Management**: Tokens are server+tenant specific
- **Access Control**: Cross-tenant operations require appropriate authentication

## Integration

monk-cli integrates with:
- **Monk API**: Direct HTTP API communication
- **CI/CD Pipelines**: Automation-friendly JSON output
- **Shell Scripts**: Unix-familiar commands and exit codes
- **JSON Tools**: jq, yq for advanced data processing
- **Version Control**: Configuration files suitable for tracking

For complete usage documentation, see the `docs/` directory with comprehensive command references and examples.