#!/opt/bin/bash

set -euo pipefail

# Check backup source directory before running backup.
# Verifies existence, readability, and at least one subdirectory.
# Sets DISK_STATUS to [OK] or [FAIL].

backup_disk_check() {
    local root="${BACKUP_SOURCE_DIR:-}"
    local has_entries=0
    local invalid_entries=""

    DISK_STATUS="[FAIL]"

    if [[ -z "$root" ]]; then
        log_error "backup_disk_check: BACKUP_SOURCE_DIR is not set."
        return 1
    fi

    if [[ ! -d "$root" ]]; then
        log_error "backup_disk_check: directory does not exist: ${root}"
        return 1
    fi

    if [[ ! -r "$root" ]]; then
        log_error "backup_disk_check: directory is not readable: ${root}"
        return 1
    fi

    local entry
    shopt -s nullglob
    for entry in "$root"/*; do
        [[ ! -e "$entry" ]] && continue

        if [[ -f "$entry" ]]; then
            invalid_entries+="${entry##*/} (file), "
            continue
        fi

        if [[ -d "$entry" ]]; then
            has_entries=1
            continue
        fi

        invalid_entries+="${entry##*/} (unsupported type), "
    done
    shopt -u nullglob

    if [[ -n "$invalid_entries" ]]; then
        invalid_entries="$(printf '%s\n' "$invalid_entries" | sed 's/, $//')"
        log_warn "Invalid entries in ${root}: ${invalid_entries}"
        DISK_STATUS="[FAIL]"
        return 1
    fi

    if [[ "$has_entries" -eq 0 ]]; then
        log_warn "No directories found under ${root} for backup."
        DISK_STATUS="[FAIL]"
        return 1
    fi

    DISK_STATUS="[OK]"
    log_info "Disk checkup: [OK] for ${root}"
    return 0
}
