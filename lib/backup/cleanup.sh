#!/bin/sh

cleanup() {
    local log repo repo_name result failed=0

    if ! import -f /opt/root/etc/restic/restic.conf \
        -f /opt/root/secrets/backup/.restic.env \
        -f /opt/root/etc/backup/backup.conf; then
        log -e "Failed to import configuration files."
        return 1
    fi
    
    log -i "Starting cleanup..."
  
    for repo in "$BACKUP_DIR"/*; do
        repo_name=$(basename "$repo")
        log -i "Cleaning repo: '$repo_name'"

        log="$(
            restic -r "$repo" forget \
            --keep-daily "$KEEP_DAILY" \
            --keep-weekly "$KEEP_WEEKLY" \
            --keep-monthly "$KEEP_MONTHLY" \
            --prune \
            2>&1
            )"
        result=$?

        printf '%s\n' "$log" | tee -a "$LOG_FILE"

        if [ "$result" -eq 0 ]; then
            log -i "Repo '$repo_name' cleanup: [OK]"
            MSG="$MSG$(
                format -b "Repo '$repo_name' cleanup: [OK]"
            )"
            [ -n "$log" ] && MSG="$MSG$(
                format -b "Stats:"
            )$(
                format -p "$(
                    parse_log --cleanup "$log"
                )"
            )"
        else
            failed=1
            log -w "Repo '$repo_name' cleanup: [FAIL]"
            MSG="$MSG$(
                format -b "Repo '$repo_name' cleanup: [FAIL]"
            )"
            [ -n "$log" ] && MSG="$MSG$(
                format -p "$log"
            )"
        fi    
    done

    if [ ! "$failed" -eq 0 ]; then
        return 1
    fi
    return 0
}