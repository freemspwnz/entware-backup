#!/opt/bin/bash
#
# Logging for Entware: logger utility with level mapping to syslog.
# No systemd — use logger -t "backup" -p facility.priority.
#
# Levels: INFO -> user.info, WARN -> user.warning, ERROR -> user.err, DEBUG -> user.debug
#
# Optimization: for bulk output use a single pipe to logger for a block of commands,
# not log_* on every line (see main.sh).

LOG_TAG="${LOG_TAG:-backup}"

# Log file (optional). If set, lines are duplicated to file (tee).
# Rotation: configure logrotate for /opt/var/log/backup.log
BACKUP_LOG_FILE="${BACKUP_LOG_FILE:-}"

_log() {
    local level="$1"
    local msg="$2"
    local priority

    [[ "$level" == "DEBUG" && "${BACKUP_DEBUG:-0}" != "1" ]] && return 0

    case "$level" in
        ERROR) priority="user.err" ;;
        WARN)  priority="user.warning" ;;
        INFO)  priority="user.info" ;;
        DEBUG) priority="user.debug" ;;
        *)     priority="user.info" ;;
    esac

    if [[ -n "${BACKUP_LOG_FILE:-}" ]]; then
        printf '%s [%s] %s: %s\n' "$(date '+%Y-%m-%d %H:%M:%S')" "$level" "$LOG_TAG" "$msg" \
            | tee -a "${BACKUP_LOG_FILE}" | logger -t "${LOG_TAG}" -p "$priority"
    else
        printf '%s [%s] %s: %s\n' "$(date '+%Y-%m-%d %H:%M:%S')" "$level" "$LOG_TAG" "$msg" \
            | logger -t "${LOG_TAG}" -p "$priority"
    fi
}

log_info() {
    _log "INFO" "$*"
}

log_warn() {
    _log "WARN" "$*"
}

log_error() {
    _log "ERROR" "$*"
}

log_debug() {
    _log "DEBUG" "$*"
}

# Send arbitrary output to logger (and optionally to file).
# Usage: backup_log_stream <<< "text"  or  backup_log_stream < file
backup_log_stream() {
    local priority="${1:-user.info}"
    if [[ -n "${BACKUP_LOG_FILE:-}" ]]; then
        tee -a "${BACKUP_LOG_FILE}" | logger -t "${LOG_TAG}" -p "$priority"
    else
        logger -t "${LOG_TAG}" -p "$priority"
    fi
}
