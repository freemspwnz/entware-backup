#!/bin/sh

disk_checkup() {
    local has_repos=0
    local invalid_entries=""
    local entry

    if ! import -f /opt/root/etc/backup/backup.conf; then
        log -e "Failed to import configuration files."
        return 1
    fi
    
    for entry in "$BACKUP_DIR"/*; do
        # If there's nothing - won't start
        [ ! -e "$entry" ] && continue

        # No files
        if [ -f "$entry" ]; then
            invalid_entries="${invalid_entries}$(basename "$entry") (file), "
            continue
        fi

        # No dirs without config allowed
        if [ -d "$entry" ]; then
            [ "$(basename "$entry")" = "lost+found" ] && continue
            if [ ! -f "$entry/config" ]; then
                invalid_entries="${invalid_entries}$(basename "$entry") (no config), "
                continue
            fi
            has_repos=1
            continue
        fi

        # Unsupported type (symlink and etc.) is also considered an error
        invalid_entries="${invalid_entries}$(basename "$entry") (unsupported type), "
    done

    # If there are invalid entries - immediately fail
    if [ -n "$invalid_entries" ]; then
        # Trim the last comma and space
        invalid_entries=$(
            printf '%s\n' "$invalid_entries" \
                | sed 's/, $//'
        )
        log -w "Invalid entries in $BACKUP_DIR: $invalid_entries"
        log -e "Disk checkup: [FAIL]"
        MSG="$MSG$(
            format -b "Invalid entries in $BACKUP_DIR!"
        )$(
            format -b "Entries:"
        )$(
            format -p "$invalid_entries"
        )$(
            format -b "Disk checkup: [FAIL]"
        )"
        return 1
    fi

    # If there are no valid repos - immediately fail
    if [ "$has_repos" -eq 0 ]; then
        log -w "No repos found in $BACKUP_DIR."
        log -e "Disk checkup: [FAIL]"
        MSG="$MSG$(
            format -b "No repos found for backup operations. Check disk."
        )$(
            format -b "Disk checkup: [FAIL]"
        )"
        return 1
    fi
    
    log -i "Disk checkup: [OK]"
    MSG="$MSG$(
        format -b "Disk checkup: [OK]"
    )"
    return 0
}