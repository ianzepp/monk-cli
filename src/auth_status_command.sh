# Check dependencies
check_dependencies

token=$(get_jwt_token)

if [ -n "$token" ]; then
    print_success "Authenticated"
    
    # Try to extract domain from token (basic decode)
    if [ "$JSON_PARSER" = "jq" ] || [ "$JSON_PARSER" = "jshon" ]; then
        # Decode JWT payload (basic base64 decode of middle part)
        payload=$(echo "$token" | cut -d'.' -f2)
        # Add padding if needed
        case $((${#payload} % 4)) in
            2) payload="${payload}==" ;;
            3) payload="${payload}=" ;;
        esac
        
        if command -v base64 &> /dev/null; then
            decoded=$(echo "$payload" | base64 -d 2>/dev/null || echo "")
            if [ -n "$decoded" ]; then
                if [ "$JSON_PARSER" = "jq" ]; then
                    tenant=$(echo "$decoded" | jq -r '.tenant' 2>/dev/null || echo "unknown")
                    database=$(echo "$decoded" | jq -r '.database' 2>/dev/null || echo "unknown")
                    exp=$(echo "$decoded" | jq -r '.exp' 2>/dev/null || echo "unknown")
                elif [ "$JSON_PARSER" = "jshon" ]; then
                    tenant=$(echo "$decoded" | jshon -e tenant -u 2>/dev/null || echo "unknown")
                    database=$(echo "$decoded" | jshon -e database -u 2>/dev/null || echo "unknown")
                    exp=$(echo "$decoded" | jshon -e exp -u 2>/dev/null || echo "unknown")
                fi
                
                echo "Tenant: $tenant"
                echo "Database: $database"
                if [ "$exp" != "unknown" ] && [ "$exp" != "null" ]; then
                    if command -v date &> /dev/null; then
                        exp_date=$(date -r "$exp" 2>/dev/null || echo "unknown")
                        echo "Expires: $exp_date"
                    fi
                fi
            fi
        fi
    fi
    
    
    # Show current context information
    current_server=$(jq -r '.current_server // empty' "$ENV_CONFIG" 2>/dev/null)
    current_tenant=$(jq -r '.current_tenant // empty' "$ENV_CONFIG" 2>/dev/null)
    current_user=$(jq -r '.current_user // empty' "$ENV_CONFIG" 2>/dev/null)
    
    echo "Server: $current_server"
    echo "Tenant: $current_tenant"
    echo "User: $current_user"
else
    print_info_always "Not authenticated"
    print_info_always "Use 'monk auth login TENANT USERNAME' or 'monk auth import TENANT USERNAME' to authenticate"
fi