#!/bin/sh

. /opt/root/lib/import/import_file.sh
. /opt/root/lib/import/import_lib.sh
. /opt/root/lib/import/show_help.sh
. /opt/root/lib/shared/check_var.sh


import() {

    while [ $# -gt 0 ]; do
        case "$1" in
            --file|-f)
                if ! check_var "$2"; then
                    echo "No file provided for option $1." >&2
                    return 1
                fi
                import_file "$2"    
                shift 2
                continue
                ;;
            --lib|-l)
                if ! check_var "$2"; then
                    echo "No dir provided for option $1." >&2
                    return 1
                fi
                import_lib "$2"
                shift 2
                continue
                ;;
            --help|-h)
                show_help
                return 0
                ;;
            *)
                echo "Unknown OPTION: $1" >&2
                echo "Type 'import -h' for a list of available options."
                return 1
                ;;
        esac
        shift
    done
}
