#!/bin/bash

# migrate-commands.sh - Reorganize bashly command files into subdirectory structure
#
# This script converts from flat structure:
#   src/auth_login_command.sh
# To nested structure:
#   src/commands/auth/login.sh

set -e

SRC_DIR="src"
COMMANDS_DIR="$SRC_DIR/commands"

echo "Starting command file reorganization..."
echo

# Create commands directory if it doesn't exist
if [ ! -d "$COMMANDS_DIR" ]; then
    echo "Creating $COMMANDS_DIR directory..."
    mkdir -p "$COMMANDS_DIR"
fi

# Counter for tracking progress
total=0
moved=0

# Find all *_command.sh files in src/ (excluding subdirectories)
while IFS= read -r file; do
    
    total=$((total + 1))
    
    # Extract filename without path
    filename=$(basename "$file")
    
    # Remove _command.sh suffix to get the command parts
    # Example: auth_login_command.sh -> auth_login
    command_name="${filename%_command.sh}"
    
    # Split by underscore to get command hierarchy
    # Example: auth_login -> auth/login
    # Example: root_tenant_list -> root/tenant/list
    
    # Convert underscores to path separators
    # This handles multi-level commands like root_tenant_list
    target_path="${command_name//_//}.sh"
    
    # Determine the target directory and filename
    target_dir="$COMMANDS_DIR/$(dirname "$target_path")"
    target_file="$COMMANDS_DIR/$target_path"
    
    # Create target directory if it doesn't exist
    if [ ! -d "$target_dir" ]; then
        echo "Creating directory: $target_dir"
        mkdir -p "$target_dir"
    fi
    
    # Move and rename the file
    echo "Moving: $file -> $target_file"
    git mv "$file" "$target_file"
    
    moved=$((moved + 1))
done < <(find "$SRC_DIR" -maxdepth 1 -name "*_command.sh" -type f)

echo
echo "Migration complete!"
echo "Total files processed: $total"
echo "Files moved: $moved"
echo
echo "New structure created in: $COMMANDS_DIR"
echo
echo "Next steps:"
echo "1. Run 'bashly generate' to regenerate the CLI with new structure"
echo "2. Test the generated bin/monk script"
echo "3. If everything works, commit the changes"
