#!/bin/sh

parse_log() {
    local type="$1"
    local log="$2"

    case "$type" in
        "--cleanup")
            printf '%s\n' "$log" \
                | grep -E "keep [0-9]+ snapshots|snapshots have been removed|this removes|remaining|frees [0-9]+"
            return 0
            ;;
        "--checkup")
            printf '%s\n' "$log" \
                | grep -E "snapshots|no errors were found"
            return 0
            ;;
        "--backup")
            printf '%s\n' "$log" \
                | grep -E "Files:|Dirs:|Added to the repository:"
            return 0
            ;;
        *)
            echo "Unknown log type: $type"
            return 1
    esac
}