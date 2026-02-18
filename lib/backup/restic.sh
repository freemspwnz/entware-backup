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

    "${RESTIC_BIN}" -r "${RESTIC_REPOSITORY}" backup "$@" >"$tmp_log" 2>&1
    BACKUP_RESTIC_EXIT=$?
    BACKUP_RESTIC_LOG="$(cat "$tmp_log")"
}

backup_extract_restic_stats() {
    printf '%s\n' "${BACKUP_RESTIC_LOG:-}" | grep -E 'Files:|Dirs:|Added to the repository' || true
}

# Retention policy (from backup.conf: KEEP_DAILY, KEEP_WEEKLY, KEEP_MONTHLY)
# Router always runs forget for all repositories in the directory that contains RESTIC_REPOSITORY.
# Builds CLEANUP_REPORT for Telegram (Repo 'name' prune: [OK]/[FAIL], Stats: <pre>...</pre>).
backup_forget() {
    local keep_daily="${KEEP_DAILY:-7}"
    local keep_weekly="${KEEP_WEEKLY:-4}"
    local keep_monthly="${KEEP_MONTHLY:-3}"
    local out
    CLEANUP_REPORT=""

    # Derive repositories root from RESTIC_REPOSITORY (router mode)
    local repo_root=""
    if [[ -n "${RESTIC_REPOSITORY:-}" && "${RESTIC_REPOSITORY}" == /* ]]; then
        repo_root="${RESTIC_REPOSITORY%/*}"
    fi

    if [[ -n "${repo_root}" && -d "${repo_root}" ]]; then
        local repo
        local repo_name
        local had_error=0
        for repo in "${repo_root}"/*; do
            [[ -d "$repo" ]] || continue
            repo_name="${repo##*/}"
            log_info "Pruning repository: ${repo}"
            out="$("${RESTIC_BIN}" -r "${repo}" forget \
                --keep-daily "$keep_daily" \
                --keep-weekly "$keep_weekly" \
                --keep-monthly "$keep_monthly" \
                --prune 2>&1)" || true
            local exit_code=$?
            local status="[OK]"
            [[ "$exit_code" -ne 0 ]] && { had_error=1; status="[FAIL]"; log_warn "Prune reported an error for repository: ${repo}"; } || log_info "Prune completed successfully for repository: ${repo}"
            local prune_stats
            prune_stats="$(printf '%s\n' "$out" | grep -E 'keep [0-9]+ snapshots|removed|remaining|frees [0-9]+|prune|unchanged' | head -20)" || prune_stats="(no stats)"
            CLEANUP_REPORT="${CLEANUP_REPORT}Repo '${repo_name}' prune: <b>${status}</b>
Stats:
<pre>${prune_stats}</pre>
"
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
    local repo_name="${RESTIC_REPOSITORY##*/}"
    local status="[OK]"
    [[ "$BACKUP_FORGET_EXIT" -ne 0 ]] && status="[FAIL]"
    local prune_stats
    prune_stats="$(printf '%s\n' "$out" | grep -E 'keep [0-9]+ snapshots|removed|remaining|frees [0-9]+|prune|unchanged' | head -20)" || prune_stats="(no stats)"
    CLEANUP_REPORT="Repo '${repo_name}' prune: <b>${status}</b>
Stats:
<pre>${prune_stats}</pre>
"
    return "$BACKUP_FORGET_EXIT"
}

# Builds CHECK_REPORT for Telegram (Repo 'name' check: [OK]/[FAIL], Stats: <pre>...</pre>).
backup_integrity_check() {
    local repo_root=""
    if [[ -n "${RESTIC_REPOSITORY:-}" && "${RESTIC_REPOSITORY}" == /* ]]; then
        repo_root="${RESTIC_REPOSITORY%/*}"
    fi
    CHECK_REPORT=""

    if [[ -n "${repo_root}" && -d "${repo_root}" ]]; then
        local repo
        local repo_name
        local had_error=0
        for repo in "${repo_root}"/*; do
            [[ -d "$repo" ]] || continue
            repo_name="${repo##*/}"
            log_info "Running restic check for repository: ${repo}"
            local out
            out="$("${RESTIC_BIN}" -r "${repo}" check 2>&1)" || true
            local exit_code=$?
            local status="[OK]"
            [[ "$exit_code" -ne 0 ]] && { had_error=1; status="[FAIL]"; log_warn "Restic check reported issues for repository: ${repo}"; } || log_info "Restic check completed successfully for repository: ${repo}"
            local check_stats
            check_stats="$(printf '%s\n' "$out" | grep -E 'check|no errors|pack|snapshot' | head -15)" || check_stats="(no errors were found)"
            [[ -z "${check_stats}" ]] && check_stats="(no errors were found)"
            CHECK_REPORT="${CHECK_REPORT}Repo '${repo_name}' check: <b>${status}</b>
Stats:
<pre>${check_stats}</pre>
"
        done
        BACKUP_CHECK_EXIT=$had_error
        return "$had_error"
    fi

    # Fallback: single repository
    log_info "Running restic check for repository: ${RESTIC_REPOSITORY}"
    local out
    out="$("${RESTIC_BIN}" -r "${RESTIC_REPOSITORY}" check 2>&1)" || true
    BACKUP_CHECK_EXIT=$?
    local repo_name="${RESTIC_REPOSITORY##*/}"
    local status="[OK]"
    [[ "$BACKUP_CHECK_EXIT" -ne 0 ]] && status="[FAIL]"
    local check_stats
    check_stats="$(printf '%s\n' "$out" | grep -E 'check|no errors|pack|snapshot' | head -15)" || check_stats="(no errors were found)"
    [[ -z "${check_stats}" ]] && check_stats="(no errors were found)"
    CHECK_REPORT="Repo '${repo_name}' check: <b>${status}</b>
Stats:
<pre>${check_stats}</pre>
"
    return "$BACKUP_CHECK_EXIT"
}
