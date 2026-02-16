#!/bin/sh

integrity_check() {
    local log repo repo_name result failed=0

    if ! import -f /opt/root/etc/restic/restic.conf \
        -f /opt/root/secrets/backup/.restic.env \
        -f /opt/root/etc/backup/backup.conf; then
        log -e "Failed to import configuration files."
        return 1
    fi
    
    log -i "Starting integrity check..."

    for repo in "$BACKUP_DIR"/*; do
        repo_name=$(basename "$repo")
        log -i "Checking repo: '$repo_name'"

        log="$(
          restic -r "$repo" check \
          2>&1
        )"
        result=$?

        printf '%s\n' "$log" | tee -a "$LOG_FILE"

        if [ "$result" -eq 0 ]; then
            MSG="$MSG$(
                format -b "Repo '$repo_name' checkup: [OK]"
            )"
            [ -n "$log" ] && MSG="$MSG$(
                format -b "Stats:"
            )$(
                format -p "$(
                    parse_log --checkup "$log"
                )"
            )"
            log -i "Repo '$repo_name' checkup: [OK]"
        else
            failed=1
            MSG="$MSG$(
                format -b "Repo '$repo_name' checkup: [FAIL]"
            )"
            [ -n "$log" ] && MSG="$MSG$(
                format -p "$log"
            )"
            log -w "Repo '$repo_name' checkup: [FAIL]"
        fi
    done

    if [ ! "$failed" -eq 0 ]; then
        return 1
    fi
    return 0
}