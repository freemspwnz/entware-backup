#!/opt/bin/bash

set -euo pipefail

PATH="/opt/bin:/opt/sbin:/usr/bin:/usr/sbin:/bin:/sbin"

LIB_ROOT_DEFAULT="/opt/lib"
LIB_ROOT="${LIB_ROOT:-$LIB_ROOT_DEFAULT}"
BACKUP_LIB_DIR="${LIB_ROOT}/backup"

# Logging (logger -t backup -p user.info/err/...)
# shellcheck source=/dev/null
source "${LIB_ROOT}/logger.sh"

# Backup modules
# shellcheck source=/dev/null
source "${BACKUP_LIB_DIR}/config.sh"
# shellcheck source=/dev/null
source "${BACKUP_LIB_DIR}/disk_check.sh"
# shellcheck source=/dev/null
source "${BACKUP_LIB_DIR}/restic.sh"
# shellcheck source=/dev/null
source "${BACKUP_LIB_DIR}/report.sh"
# shellcheck source=/dev/null
source "${BACKUP_LIB_DIR}/main.sh"

# shellcheck source=/dev/null
source "${LIB_ROOT}/telegram.sh"

backup_run "$@"
