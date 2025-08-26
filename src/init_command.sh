# Get the configuration path
if [[ -n "${args[path]}" ]]; then
    config_path="${args[path]}"
else
    config_path="${HOME}/.config/monk"
fi

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
RED='\033[0;31m'
NC='\033[0m' # No Color

echo -e "${BLUE}Initializing Monk configuration directory...${NC}"
echo "Configuration path: ${config_path}"

# Create directory if it doesn't exist
if [[ ! -d "$config_path" ]]; then
    echo -e "${YELLOW}→${NC} Creating directory: ${config_path}"
    mkdir -p "$config_path"
else
    echo -e "${GREEN}✓${NC} Directory already exists: ${config_path}"
fi

# Initialize servers.json
servers_file="${config_path}/servers.json"
if [[ ! -f "$servers_file" ]]; then
    echo -e "${YELLOW}→${NC} Creating servers.json"
    cat > "$servers_file" << 'EOF'
{
  "servers": {
    "local": {
      "hostname": "localhost",
      "port": 9001,
      "protocol": "http",
      "description": "Local development server",
      "added_at": "",
      "last_ping": "",
      "status": "unknown"
    }
  },
  "current": "local"
}
EOF
    echo -e "${GREEN}✓${NC} Created servers.json"
else
    echo -e "${GREEN}✓${NC} servers.json already exists"
fi

# Initialize env.json
env_file="${config_path}/env.json"
if [[ ! -f "$env_file" ]]; then
    echo -e "${YELLOW}→${NC} Creating env.json"
    cat > "$env_file" << 'EOF'
{
  "DATABASE_URL": "postgresql://user:password@localhost:5432/monk-api-auth",
  "NODE_ENV": "development",
  "PORT": "9001",
  "JWT_SECRET": "development-test-secret-key-change-in-production"
}
EOF
    echo -e "${GREEN}✓${NC} Created env.json"
else
    echo -e "${GREEN}✓${NC} env.json already exists"
fi

# Initialize test.json
test_file="${config_path}/test.json"
if [[ ! -f "$test_file" ]]; then
    echo -e "${YELLOW}→${NC} Creating test.json"
    cat > "$test_file" << 'EOF'
{
  "base_directory": "/tmp/monk-builds",
  "default_settings": {
    "git_remote": "https://github.com/ianzepp/monk-api.git",
    "default_port_range": {
      "git_tests": {
        "start": 3000,
        "end": 3999
      }
    }
  },
  "runs": {}
}
EOF
    echo -e "${GREEN}✓${NC} Created test.json"
else
    echo -e "${GREEN}✓${NC} test.json already exists"
fi

echo -e "${GREEN}✓${NC} Monk configuration initialized successfully!"
echo
echo "Configuration files created in: ${config_path}"
echo "  - servers.json: Server configurations and current selection"
echo "  - env.json: Environment variables for API connection"
echo "  - test.json: Test run configurations and history"
echo
echo "Next steps:"
echo "  1. Update servers.json with your server details"
echo "  2. Configure env.json with your database and API settings"
echo "  3. Use 'monk servers add' to register additional servers"