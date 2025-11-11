# 40-Describe CLI: Schema Management Tests

Tests for the `monk describe` commands providing complete schema lifecycle management (CRUD operations) via the CLI interface.

**Scope:**
- Schema creation from JSON with various field types and constraints
- Schema retrieval and listing operations
- Schema updates and structural modifications
- Schema deletion and soft delete functionality
- JSON Schema validation and format support
- Error handling and edge cases
- Integration with authentication and tenant management
- Format output (text vs JSON)

**Test Focus:**
- Complete CRUD lifecycle (Create, Read, Update, Delete)
- JSON input validation and error handling
- Schema evolution and safe updates
- System schema protection
- Multi-format output support
- Integration with existing data operations
- Command-line interface usability

**Test Files:**
- `01-select-schema.test.sh` - Basic schema retrieval operations
- `02-create-schema.test.sh` - Schema creation with various JSON structures
- `03-update-schema.test.sh` - Schema modification and updates
- `04-delete-schema.test.sh` - Schema deletion and protection
- `05-error-handling.test.sh` - Error cases and edge conditions
- `06-format-output.test.sh` - Text vs JSON output formatting
- `07-complex-schemas.test.sh` - Complex nested schemas and relationships