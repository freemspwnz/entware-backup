#!/bin/sh

. /opt/root/lib/import/import.sh

log() {

    import \
        -l "/opt/root/lib/log" \
        -l "/opt/root/lib/shared"

    if ! check_var "$2"; then
        echo "No text provided for option '$1'." >&2
        return 1
    fi

    case "$1" in
        --info|-i)
            echo "[I] $(date '+%Y-%m-%d %H:%M:%S'): $2" | tee -a $LOG_FILE
            return 0
            ;;
        --warning|-w) 
            echo "[W] $(date '+%Y-%m-%d %H:%M:%S'): $2" | tee -a $LOG_FILE
            return 0
            ;;
        --error|-e)
            echo "[E] $(date '+%Y-%m-%d %H:%M:%S'): $2" | tee -a $LOG_FILE
            return 0
            ;;
        --debug|-d)
            echo "[D] $(date '+%Y-%m-%d %H:%M:%S'): $2" | tee -a $LOG_FILE
            return 0
            ;;
        --help|-h)
            show_help
            return 0
            ;;
        *)
            echo "Unknown OPTION: $1" >&2
            echo "Type 'log -h' for a list of available options."
            return 1
            ;;
    esac
}