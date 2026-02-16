#!/bin/sh

restic_backup() {
    local log repo repo_name result

    if ! import -f /opt/root/etc/restic/restic.conf \
        -f /opt/root/secrets/backup/.restic.env \
        -f /opt/root/etc/backup/backup.conf; then
        log -e "Failed to import configuration files."
        return 1
    fi

    log -i "Starting restic backup..."

    # Backup everything, excluding .*, log and temp files if they exist
    repo_name=$(basename "$RESTIC_REPOSITORY")
    log -i "Backing up repo: $repo_name"
    log="$(
        restic backup /opt/root \
            --tag "$TAGS" \
            --exclude "/opt/root/.*" \
            --exclude "/opt/root/var/log" \
            --exclude "/opt/root/tmp" \
            2>&1
    )"
    result=$?

    printf '%s\n' "$log" | tee -a "$LOG_FILE"

    if [ "$result" -eq 0 ]; then
        MSG="$MSG$(
            format -b "Repo: '$repo_name' backup: [OK]"
        )"
        [ -n "$log" ] && MSG="$MSG$(
            format -b "Stats:"
        )$(
            format -p "$(
                parse_log --backup "$log"
            )"
        )"
        log -i "Repo: '$repo_name' backup: [OK]"
        return 0
    else
        MSG="$MSG$(
            format -b "Repo: '$repo_name' backup: [FAIL]"
        )"
        [ -n "$log" ] && MSG="$MSG$(
            format -p "$log"
        )"
        log -e "Repo: '$repo_name' backup: [FAIL]"
        return 1
    fi
}