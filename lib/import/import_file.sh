#!/bin/sh
. /opt/root/lib/import/validate_var.sh

import_file() {
    local key value
    # Existance check
    if [ ! -f "$1" ]; then
        echo "File not found: $1" >&2
        return 1
    fi
    
    # Access check
    if [ ! -r "$1" ]; then
        echo "File not readable: $1" >&2
        return 1
    fi

    while IFS='=' read -r key value || [ -n "$key" ]; do
        # Skipping empty lines and comments
        [ -z "$key" ] && continue
        case "$key" in
            \#*) 
                continue
                ;;
        esac
        if ! validate_var "$key" "$value"; then
            return 1
        fi
        export "$key=$value"
    done < "$1"
    
    return 0
}