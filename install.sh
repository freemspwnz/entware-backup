#!/opt/bin/bash
#
# Install entware-backup into /opt (Keenetic Entware).
# Does not overwrite existing /opt/usr/local/etc/backup/backup.conf or /opt/usr/local/secrets/.backup.env.
#
# Usage: ./install.sh [REPO_ROOT]
#   REPO_ROOT — repository root (default: directory containing this script).

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="${1:-$SCRIPT_DIR}"

BIN_DIR="/opt/usr/local/bin"
LIB_ROOT="/opt/usr/local/lib"
BACKUP_LIB_DIR="${LIB_ROOT}/backup"
ETC_BACKUP="/opt/usr/local/etc/backup"
SECRETS_DIR="/opt/usr/local/secrets"
INIT_D="/opt/etc/init.d"
LOGROTATE_D="/opt/etc/logrotate.d"
VAR_RUN="/opt/var/run"
VAR_LOG="/opt/var/log"

echo "Installing from: ${REPO_ROOT}"

mkdir -p "${BIN_DIR}"
mkdir -p "${LIB_ROOT}"
mkdir -p "${BACKUP_LIB_DIR}"
mkdir -p "${ETC_BACKUP}"
mkdir -p "${SECRETS_DIR}"
mkdir -p "${INIT_D}"
mkdir -p "${LOGROTATE_D}"
mkdir -p "${VAR_RUN}"
mkdir -p "${VAR_LOG}"

install -m 755 "${REPO_ROOT}/bin/backup.sh" "${BIN_DIR}/backup.sh"

install -m 644 "${REPO_ROOT}/lib/logger.sh"   "${BACKUP_LIB_DIR}/logger.sh"
install -m 644 "${REPO_ROOT}/lib/telegram.sh" "${BACKUP_LIB_DIR}/telegram.sh"

for f in config.sh disk_check.sh main.sh report.sh restic.sh; do
    install -m 644 "${REPO_ROOT}/lib/backup/${f}" "${BACKUP_LIB_DIR}/${f}"
done

if [[ ! -f "${ETC_BACKUP}/backup.conf" ]]; then
    install -m 640 "${REPO_ROOT}/etc/backup/backup.conf.example" "${ETC_BACKUP}/backup.conf"
    echo "Created ${ETC_BACKUP}/backup.conf from example; edit and set RESTIC_REPOSITORY, BACKUP_SOURCE_DIR."
else
    echo "Leaving existing ${ETC_BACKUP}/backup.conf unchanged."
fi

install -m 755 "${REPO_ROOT}/etc/init.d/S99backup" "${INIT_D}/S99backup"
install -m 644 "${REPO_ROOT}/etc/logrotate.d/backup" "${LOGROTATE_D}/backup"

if [[ ! -f "${SECRETS_DIR}/.backup.env" ]]; then
    echo "Create ${SECRETS_DIR}/.backup.env with RESTIC_PASSWORD and optionally TG_TOKEN, TG_CHAT_ID."
else
    echo "Leaving existing ${SECRETS_DIR}/.backup.env unchanged."
fi

if [[ -f /opt/etc/profile ]]; then
  if ! grep -q "/opt/usr/local/bin" /opt/etc/profile; then
    echo 'export PATH="/opt/usr/local/bin:$PATH"' >> /opt/etc/profile
  fi
fi

echo "Done. Run backup: /opt/usr/local/bin/backup.sh"
echo "Init: ${INIT_D}/S99backup start|stop|restart|status"
