#!/bin/sh
# Library of functions importing utility
# Imports every file in given directory

import_lib() {
    local func

    if [ ! -d "$1" ]; then
        echo "Directory $1 doesn't exist." >&2
        return 1
    fi

    for func in "$1"/*; do
        [ -e "$func" ] || continue
        [ -d "$func" ] && continue
        [ "$(readlink -f "$func")" = "$(readlink -f "$0")" ] && continue
        . "$func"
    done

    return 0
}