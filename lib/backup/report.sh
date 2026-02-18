#!/opt/bin/bash

set -euo pipefail

# Build and send backup report to Telegram (HTML).
# Uses DISK_STATUS, BACKUP_RESTIC_LOG, CLEANUP_REPORT, CHECK_REPORT, tg_send_html from lib/telegram.sh

backup_build_telegram_message() {
    local host="$1"
    local repo_name="$2"
    local backup_status="$3"
    local backup_status_text="$4"
    local stats="$5"
    local raw_log_tail="$6"
    local disk_status="${DISK_STATUS:-[UNKNOWN]}"

    cat <<EOF
Host: <b>${host}</b>
Disk checkup: <b>${disk_status}</b>
Repo '${repo_name}' backup: <b>${backup_status}</b>
Stats:
<pre>${stats}</pre>
Backup ${backup_status_text}.
EOF

    if [[ -n "${raw_log_tail}" ]]; then
        cat <<EOF

<b>Restic log (tail):</b>
<pre>${raw_log_tail}</pre>
EOF
    fi

    if [[ -n "${CLEANUP_REPORT:-}" ]]; then
        cat <<EOF

${CLEANUP_REPORT}
Prune completed successfully.
EOF
    fi

    if [[ -n "${CHECK_REPORT:-}" ]]; then
        cat <<EOF

${CHECK_REPORT}
Integrity check completed successfully.
EOF
    fi
}

backup_send_telegram_report() {
    local host="$1"
    local repo_name="$2"
    local backup_status="$3"
    local backup_status_text="$4"
    local stats="$5"
    local raw_log_tail="${6:-}"

    local msg
    msg="$(backup_build_telegram_message "$host" "$repo_name" "$backup_status" "$backup_status_text" "$stats" "$raw_log_tail")"
    tg_send_html "${msg}"
}
