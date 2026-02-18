#!/opt/bin/bash

set -euo pipefail

# Backup orchestration for Entware: config, disk check, restic backup/forget/check, Telegram report.
# Bulk restic output goes to logger via a single pipe (see restic.sh).

TIMESTAMP="$(date '+%Y%m%d_%H%M%S')"

backup_run() {
    trap 'log_warn "Backup interrupted"' INT TERM HUP

    backup_load_config
    local host
    host="$(hostname)"

    log_info "Starting backup. Host: ${host}"

    DISK_STATUS="[UNKNOWN]"
    if ! backup_disk_check; then
        log_warn "Continuing backup despite disk check failure."
    fi

    backup_check_repository

    # Backup targets: main directory + extra paths from config
    local -a BACKUP_TARGETS=()
    BACKUP_TARGETS+=("${BACKUP_SOURCE_DIR}")
    if [[ "${#EXTRA_BACKUP_PATHS[@]}" -gt 0 ]]; then
        local p
        for p in "${EXTRA_BACKUP_PATHS[@]}"; do
            BACKUP_TARGETS+=("$p")
        done
    fi

    local -a RESTIC_ARGS=()
    [[ -n "${RESTIC_TAGS:-}" ]] && RESTIC_ARGS+=(--tag "${RESTIC_TAGS}")
    [[ -n "${RESTIC_HOST:-}" ]] && RESTIC_ARGS+=(--host "${RESTIC_HOST}")
    if [[ "${#RESTIC_EXCLUDES[@]}" -gt 0 ]]; then
        local ex
        for ex in "${RESTIC_EXCLUDES[@]}"; do
            RESTIC_ARGS+=(--exclude "${ex}")
        done
    fi

    log_info "Running restic backup..."
    log_debug "Backup targets: ${BACKUP_TARGETS[*]}"

    backup_run_restic_backup "${BACKUP_TARGETS[@]}" "${RESTIC_ARGS[@]}"

    local restic_stats
    restic_stats="$(backup_extract_restic_stats)"
    local repo_name
    repo_name="${RESTIC_REPOSITORY##*/}"

    if [[ "${BACKUP_RESTIC_EXIT:-1}" -ne 0 ]]; then
        log_error "Restic backup finished with errors."
        backup_send_telegram_report "${host}" "${repo_name}" "[FAIL]" "failed" "${restic_stats:-no stats}"
        return 1
    fi

    log_info "Restic backup finished successfully."

    # Prune old snapshots
    if ! backup_forget; then
        log_warn "Prune reported an error; check repository."
    fi

    # Integrity check
    if ! backup_integrity_check; then
        log_warn "Integrity check reported issues; consider manual check."
    fi

    backup_send_telegram_report "${host}" "${repo_name}" "[OK]" "completed successfully" "${restic_stats:-no stats}"
    return 0
}
