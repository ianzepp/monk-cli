# Check dependencies
check_dependencies

# Check if we have any stored authentication
if get_jwt_token >/dev/null 2>&1; then
    remove_stored_token
    print_success "Logged out successfully"
    print_info_always "Cleared authentication for current server+tenant context"
else
    print_info_always "Already logged out (no active authentication found)"
fi