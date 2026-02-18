#!/opt/bin/bash
#
# Logging for Entware: file-only logging.
# No system logger usage; everything goes to a single log file.
#
# Levels: INFO, WARN, ERROR, DEBUG
#
# Rotation: configure logrotate for /opt/var/log/backup.log

BACKUP_LOG_FILE="${BACKUP_LOG_FILE:-/opt/var/log/backup.log}"

_log() {
    local level="$1"
    local msg="$2"

    [[ "$level" == "DEBUG" && "${BACKUP_DEBUG:-0}" != "1" ]] && return 0

    # Timestamped line without tag, only level and message
    printf '%s [%s] %s\n' "$(date '+%Y-%m-%d %H:%M:%S')" "$level" "$msg" >> "${BACKUP_LOG_FILE}"
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

# Append arbitrary output to the log file.
# Usage: backup_log_stream <<< "text"  or  backup_log_stream < file
backup_log_stream() {
    # We intentionally ignore the level here and just append raw lines.
    cat >> "${BACKUP_LOG_FILE}"
}
