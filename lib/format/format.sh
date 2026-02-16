#!/bin/sh

. /opt/root/lib/import/import.sh

format() {
    local txt

    import -l "/opt/root/lib/format" \
        -l "/opt/root/lib/shared"

    if ! check_var "$2"; then
        echo "No text provided for option $1." >&2
        return 1
    fi

    text=$(echo "$2" | sed 's/&/\&amp;/g; s/</\&lt;/g; s/>/\&gt;/g')

    case "$1" in
        --regular|-r)
            echo "$2%0A"
            return 0
            ;;
        --bold|-b)
            echo "<b>$2</b>%0A"
            return 0
            ;;
        --pre|-p)
            echo "<pre>$2</pre>%0A%0A"
            return 0
            ;;
        --help|-h)
            show_help
            return 0
            ;;
        *)
            echo "Unknown option: $1" >&2
            echo "Type 'format -h' for a list of available options."
            return 1
            ;;
    esac
}