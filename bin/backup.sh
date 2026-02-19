#!/opt/bin/bash

set -euo pipefail

PATH="/opt/usr/local/bin:/opt/bin:/opt/sbin:/usr/bin:/usr/sbin:/bin:/sbin"

BACKUP_LIB_DIR_DEFAULT="/opt/usr/local/lib/backup"
BACKUP_LIB_DIR="${BACKUP_LIB_DIR:-$BACKUP_LIB_DIR_DEFAULT}"
LIB_ROOT_DEFAULT="/opt/usr/local/lib"
LIB_ROOT="${LIB_ROOT:-$LIB_ROOT_DEFAULT}"

# shellcheck source=/dev/null
source "${LIB_ROOT}/logger.sh"
# shellcheck source=/dev/null
source "${LIB_ROOT}/telegram.sh"
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

backup_run "$@"
