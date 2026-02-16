#!/bin/sh

check_var() {
    if [ -z "$1" ] || [ "${1#-}" != "$1" ]; then
        return 1
    fi
    return 0
}
