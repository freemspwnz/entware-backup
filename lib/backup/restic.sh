#!/opt/bin/bash

set -euo pipefail

# Restic helpers for Entware.
# Variables: RESTIC_BIN (default: restic from PATH), RESTIC_REPOSITORY.
# Restic output is piped to logger in one stream (via tee when needed).

RESTIC_BIN="${RESTIC_BIN:-restic}"

backup_check_repository() {
    log_info "Checking restic repository: ${RESTIC_REPOSITORY}"
    if ! "${RESTIC_BIN}" -r "${RESTIC_REPOSITORY}" snapshots --last 1 >/dev/null 2>&1; then
        log_error "Restic repository not accessible: ${RESTIC_REPOSITORY}"
        return 1
    fi
    log_info "Restic repository is accessible."
}

# Run restic backup. Single pipe: restic -> tee (file + stdout) -> logger.
# Result: BACKUP_RESTIC_LOG, BACKUP_RESTIC_EXIT.
backup_run_restic_backup() {
    local tmp_log
    tmp_log="$(mktemp "${TMPDIR:-/tmp}/restic_log.XXXXXX" 2>/dev/null)" || tmp_log="${TMPDIR:-/tmp}/restic_log.$$"
    trap "rm -f '${tmp_log}'" RETURN

    if [[ -n "${BACKUP_LOG_FILE:-}" ]]; then
        "${RESTIC_BIN}" -r "${RESTIC_REPOSITORY}" backup "$@" 2>&1 \
            | tee -a "${BACKUP_LOG_FILE}" "$tmp_log" \
            | logger -t "${LOG_TAG:-backup}" -p user.info
    else
        "${RESTIC_BIN}" -r "${RESTIC_REPOSITORY}" backup "$@" 2>&1 \
            | tee "$tmp_log" \
            | logger -t "${LOG_TAG:-backup}" -p user.info
    fi
    BACKUP_RESTIC_EXIT=${PIPESTATUS[0]}
    BACKUP_RESTIC_LOG="$(cat "$tmp_log")"
}

backup_extract_restic_stats() {
    printf '%s\n' "${BACKUP_RESTIC_LOG:-}" | grep -E 'Files:|Dirs:|Added to the repository' || true
}

# Retention policy (from backup.conf: KEEP_DAILY, KEEP_WEEKLY, KEEP_MONTHLY)
backup_forget() {
    local keep_daily="${KEEP_DAILY:-7}"
    local keep_weekly="${KEEP_WEEKLY:-4}"
    local keep_monthly="${KEEP_MONTHLY:-3}"
    log_info "Pruning snapshots (keep-daily=${keep_daily}, keep-weekly=${keep_weekly}, keep-monthly=${keep_monthly})..."
    local out
    out="$("${RESTIC_BIN}" -r "${RESTIC_REPOSITORY}" forget \
        --keep-daily "$keep_daily" \
        --keep-weekly "$keep_weekly" \
        --keep-monthly "$keep_monthly" \
        --prune 2>&1)" || true
    BACKUP_FORGET_EXIT=$?
    if [[ -n "${BACKUP_LOG_FILE:-}" ]]; then
        printf '%s\n' "$out" | tee -a "${BACKUP_LOG_FILE}" | logger -t "${LOG_TAG:-backup}" -p user.info
    else
        printf '%s\n' "$out" | logger -t "${LOG_TAG:-backup}" -p user.info
    fi
    return "$BACKUP_FORGET_EXIT"
}

backup_integrity_check() {
    log_info "Running restic check..."
    local out
    out="$("${RESTIC_BIN}" -r "${RESTIC_REPOSITORY}" check 2>&1)" || true
    BACKUP_CHECK_EXIT=$?
    if [[ -n "${BACKUP_LOG_FILE:-}" ]]; then
        printf '%s\n' "$out" | tee -a "${BACKUP_LOG_FILE}" | logger -t "${LOG_TAG:-backup}" -p user.info
    else
        printf '%s\n' "$out" | logger -t "${LOG_TAG:-backup}" -p user.info
    fi
    return "$BACKUP_CHECK_EXIT"
}
