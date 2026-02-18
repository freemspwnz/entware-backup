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
VAR_LIB="/opt/var/lib"

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
mkdir -p "${VAR_LIB}"

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

if [[ ! -f "${SECRETS_DIR}/.backup.env" ]]; then
    echo "Create ${SECRETS_DIR}/.backup.env with RESTIC_PASSWORD and optionally TG_TOKEN, TG_CHAT_ID."
else
    echo "Leaving existing ${SECRETS_DIR}/.backup.env unchanged."
fi

install -m 755 "${REPO_ROOT}/etc/init.d/S99backup" "${INIT_D}/S99backup"
install -m 644 "${REPO_ROOT}/etc/logrotate.d/backup" "${LOGROTATE_D}/backup"

# Ensure daily logrotate cron helper exists
CRON_DAILY="/opt/etc/cron.daily"
LOGROTATE_DAILY="${CRON_DAILY}/logrotate"

mkdir -p "${CRON_DAILY}"
if [[ ! -f "${LOGROTATE_DAILY}" ]]; then
  cat > "${LOGROTATE_DAILY}" <<'EOF'
#!/bin/sh
/opt/sbin/logrotate -s /opt/var/lib/logrotate.status /opt/etc/logrotate.conf
EOF
  echo "Created ${LOGROTATE_DAILY}"
  chmod +x "${LOGROTATE_DAILY}"
fi

# Ensure backup is scheduled in cron
CRONTAB_FILE="/opt/etc/crontab"
CRONTAB_UPDATED=0

if [[ -f "${CRONTAB_FILE}" ]]; then
  if ! grep -q "/opt/usr/local/bin/backup.sh" "${CRONTAB_FILE}"; then
    echo '0 4 * * * root /opt/bin/bash /opt/usr/local/bin/backup.sh' >> "${CRONTAB_FILE}"
    CRONTAB_UPDATED=1
    echo "Added backup to cron: 0 4 * * * root /opt/bin/bash /opt/usr/local/bin/backup.sh"
  fi
else
  echo '0 4 * * * root /opt/bin/bash /opt/usr/local/bin/backup.sh' > "${CRONTAB_FILE}"
  CRONTAB_UPDATED=1
  echo "Added backup to cron: 0 4 * * * root /opt/bin/bash /opt/usr/local/bin/backup.sh"
fi

if [[ "${CRONTAB_UPDATED}" -eq 1 && -x /opt/etc/init.d/S10cron ]]; then
  /opt/etc/init.d/S10cron restart || true
fi

if [[ -f /opt/etc/profile ]]; then
  if ! grep -q "/opt/usr/local/bin" /opt/etc/profile; then
    echo 'export PATH="/opt/usr/local/bin:$PATH"' >> /opt/etc/profile
  fi
fi

echo "Done. Run backup: /opt/usr/local/bin/backup.sh"
echo "Init: ${INIT_D}/S99backup start|stop|restart|status"
