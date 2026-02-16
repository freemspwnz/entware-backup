#!/bin/sh

validate_var() {
    local name val

    # Removing spaces
    name=$(printf '%s\n' "$1" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')

    # Removing spaces and quotation marks
    val=$(printf '%s\n' "$2" \
        | sed 's/^[[:space:]]*//;s/[[:space:]]*$//' \
        | sed "s/^['\"]//;s/['\"]$//")

    # Name validity check
    case "$name" in
        ''|*[!a-zA-Z0-9_]*|[0-9]*)
            echo "Invalid variable name: '$name'" >&2
            return 1
            ;;
    esac

    key=$name
    value=$val
    return 0
}