#!/opt/bin/bash

set -euo pipefail

# Restic helpers for Entware (router role).
# Variables:
#   RESTIC_BIN          - restic binary (default: restic from PATH)
#   RESTIC_REPOSITORY   - main repository path (local on router)
# Restic output is captured into memory for stats/Telegram, but not written raw into LOG_FILE.

RESTIC_BIN="${RESTIC_BIN:-restic}"

backup_check_repository() {
    log_info "Checking restic repository: ${RESTIC_REPOSITORY}"
    if ! "${RESTIC_BIN}" -r "${RESTIC_REPOSITORY}" snapshots --last 1 >/dev/null 2>&1; then
        log_error "Restic repository not accessible: ${RESTIC_REPOSITORY}"
        return 1
    fi
    log_info "Restic repository is accessible."
}

# Run restic backup. Single pipe: restic -> tee (stdout + tmp file).
# Result: BACKUP_RESTIC_LOG, BACKUP_RESTIC_EXIT.
backup_run_restic_backup() {
    local tmp_log
    tmp_log="$(mktemp "${TMP:-/opt/tmp}/restic_log.XXXXXX" 2>/dev/null)" || tmp_log="${TMP:-/opt/tmp}/restic_log.$$"
    trap "rm -f '${tmp_log}'" RETURN

    "${RESTIC_BIN}" -r "${RESTIC_REPOSITORY}" backup "$@" 2>&1 \
        | tee "$tmp_log"
    BACKUP_RESTIC_EXIT=${PIPESTATUS[0]}
    BACKUP_RESTIC_LOG="$(cat "$tmp_log")"
}

backup_extract_restic_stats() {
    printf '%s\n' "${BACKUP_RESTIC_LOG:-}" | grep -E 'Files:|Dirs:|Added to the repository' || true
}

# Retention policy (from backup.conf: KEEP_DAILY, KEEP_WEEKLY, KEEP_MONTHLY)
# Router always runs forget for all repositories in the directory that contains RESTIC_REPOSITORY.
backup_forget() {
    local keep_daily="${KEEP_DAILY:-7}"
    local keep_weekly="${KEEP_WEEKLY:-4}"
    local keep_monthly="${KEEP_MONTHLY:-3}"
    local out

    # Derive repositories root from RESTIC_REPOSITORY (router mode)
    local repo_root=""
    if [[ -n "${RESTIC_REPOSITORY:-}" && "${RESTIC_REPOSITORY}" == /* ]]; then
        repo_root="${RESTIC_REPOSITORY%/*}"
    fi

    if [[ -n "${repo_root}" && -d "${repo_root}" ]]; then
        local repo
        local had_error=0
        for repo in "${repo_root}"/*; do
            [[ -d "$repo" ]] || continue
            log_info "Pruning repository: ${repo}"
            out="$("${RESTIC_BIN}" -r "${repo}" forget \
                --keep-daily "$keep_daily" \
                --keep-weekly "$keep_weekly" \
                --keep-monthly "$keep_monthly" \
                --prune 2>&1)" || true
            local exit_code=$?
            if [[ "$exit_code" -ne 0 ]]; then
                had_error=1
                log_warn "Prune reported an error for repository: ${repo}"
            else
                log_info "Prune completed successfully for repository: ${repo}"
            fi
        done
        BACKUP_FORGET_EXIT=$had_error
        return "$had_error"
    fi

    # Fallback: single repository if root dir cannot be derived
    log_info "Pruning snapshots in repository: ${RESTIC_REPOSITORY} (keep-daily=${keep_daily}, keep-weekly=${keep_weekly}, keep-monthly=${keep_monthly})..."
    out="$("${RESTIC_BIN}" -r "${RESTIC_REPOSITORY}" forget \
        --keep-daily "$keep_daily" \
        --keep-weekly "$keep_weekly" \
        --keep-monthly "$keep_monthly" \
        --prune 2>&1)" || true
    BACKUP_FORGET_EXIT=$?
    return "$BACKUP_FORGET_EXIT"
}

backup_integrity_check() {
    # Router mode: run check for all repos in directory that contains RESTIC_REPOSITORY
    local repo_root=""
    if [[ -n "${RESTIC_REPOSITORY:-}" && "${RESTIC_REPOSITORY}" == /* ]]; then
        repo_root="${RESTIC_REPOSITORY%/*}"
    fi

    if [[ -n "${repo_root}" && -d "${repo_root}" ]]; then
        local repo
        local had_error=0
        for repo in "${repo_root}"/*; do
            [[ -d "$repo" ]] || continue
            log_info "Running restic check for repository: ${repo}"
            "${RESTIC_BIN}" -r "${repo}" check >/dev/null 2>&1 || {
                had_error=1
                log_warn "Restic check reported issues for repository: ${repo}"
                continue
            }
            log_info "Restic check completed successfully for repository: ${repo}"
        done
        BACKUP_CHECK_EXIT=$had_error
        return "$had_error"
    fi

    # Fallback: single repository
    log_info "Running restic check for repository: ${RESTIC_REPOSITORY}"
    local out
    out="$("${RESTIC_BIN}" -r "${RESTIC_REPOSITORY}" check 2>&1)" || true
    BACKUP_CHECK_EXIT=$?
    return "$BACKUP_CHECK_EXIT"
}
