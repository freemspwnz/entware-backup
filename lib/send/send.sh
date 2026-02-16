#!/bin/sh

. /opt/root/lib/import/import.sh

send() {

    import -l "/opt/root/lib/shared"

    if ! check_var "$2"; then
        echo "No message provided for option $1." >&2
        return 1
    fi

    case "$1" in
        --telegram|-t)
            import -l "/opt/root/lib/send/tg" \
                -f "/opt/root/secrets/.tg.env"
            send_html "$2"
            return 0
            ;;
        --help|-h)
            show_help
            return 0
            ;;
        *)
            echo "Unknown OPTION: $1" >&2
            echo "Type 'send -h' for a list of available options."
            return 1
            ;;
    esac
}