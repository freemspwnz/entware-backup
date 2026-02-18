#!/opt/bin/bash

set -euo pipefail

# Backup configuration loader for Entware.
# Reads:
#   /opt/usr/local/etc/backup/backup.conf  — paths, arrays, options
#   /opt/usr/local/secrets/.backup.env     — secrets (RESTIC_PASSWORD, TG_TOKEN, TG_CHAT_ID)

BACKUP_CONF_PATH_DEFAULT="/opt/usr/local/etc/backup/backup.conf"
BACKUP_SECRETS_PATH_DEFAULT="/opt/usr/local/secrets/.backup.env"

backup_require_var() {
    local name="$1"
    if [[ -z "${!name:-}" ]]; then
        log_error "Required variable '${name}' is not set."
        return 1
    fi
}

backup_load_config() {
    local conf_path="${BACKUP_CONF_PATH:-$BACKUP_CONF_PATH_DEFAULT}"
    local secrets_path="${BACKUP_SECRETS_PATH:-$BACKUP_SECRETS_PATH_DEFAULT}"

    if [[ -f "$conf_path" ]]; then
        # shellcheck source=/dev/null
        source "$conf_path"
        log_debug "Loaded config: ${conf_path}"
        [[ -z "${EXTRA_BACKUP_PATHS+set}" ]] && EXTRA_BACKUP_PATHS=()
        [[ -z "${RESTIC_EXCLUDES+set}" ]] && RESTIC_EXCLUDES=()
    else
        log_error "Config file not found: ${conf_path}"
        return 1
    fi

    if [[ -f "$secrets_path" ]]; then
        set -a
        # shellcheck source=/dev/null
        source "$secrets_path"
        set +a
        log_debug "Loaded secrets: ${secrets_path}"
    else
        log_warn "Secrets file not found: ${secrets_path}. Continuing without it."
    fi

    backup_require_var "RESTIC_REPOSITORY"
    backup_require_var "BACKUP_SOURCE_DIR"
}
