# Restic Backup для Entware / Keenetic

Модульный бэкап через [Restic](https://restic.net/) для роутеров Keenetic с Entware. Логирование через `logger` (syslog), один конфиг `backup.conf`, опционально — запись в файл с ротацией через logrotate. Уведомления в Telegram.

---

## Обзор

Скрипты выполняют:

| Этап | Действие |
|------|----------|
| **1. Disk checkup** | Проверка каталога-источника `BACKUP_SOURCE_DIR`: существование, читаемость, наличие поддиректорий. |
| **2. Backup** | Резервное копирование в Restic-репозиторий (один репозиторий из конфига, исключения и доп. пути — массивами). |
| **3. Cleanup** | Политика хранения: `forget` + `prune` (keep-daily/weekly/monthly). |
| **4. Integrity check** | Проверка целостности репозитория через `restic check`. |

При успехе или ошибке в Telegram уходит краткий HTML-отчёт.

---

## Требования

- **Bash**: `/opt/bin/bash` (Entware).
- **Пакеты**: `curl`, `coreutils-install` (в стандартном Entware утилита `install` отсутствует), при SFTP — `openssh-client`.
- **Restic**: как правило, ручная установка бинарника в `/opt/bin/restic` (см. документацию Restic / релизы GitHub).

---

## Установка

Проект изолирован от opkg и стандартных путей Entware: всё своё он кладёт в `/opt/usr/local/` и не трогает `/opt/bin`, `/opt/lib` и т.п.

На устройстве с Entware (из корня репозитория):

```bash
/opt/bin/bash install.sh
```

Скрипт создаёт каталоги в `/opt/usr/local`, копирует `bin/backup.sh`, `lib/*`, пример конфига в `/opt/usr/local/etc/backup/backup.conf`, init.d-скрипт и конфиг logrotate. Существующие `backup.conf` и файл секретов не перезаписываются.

---

## Структура после установки

```
/opt/
├── usr/
│   └── local/
│       ├── bin/
│       │   └── backup.sh           # Точка входа (#!/opt/bin/bash)
│       ├── lib/
│       │   └── backup/
│       │       ├── logger.sh       # logger -t backup -p user.info/err/...
│       │       ├── telegram.sh     # Telegram Bot API
│       │       ├── config.sh       # Загрузка backup.conf и .backup.env
│       │       ├── disk_check.sh   # Проверка BACKUP_SOURCE_DIR
│       │       ├── restic.sh       # backup, forget, check (вывод в logger пайпом)
│       │       ├── report.sh       # Сборка HTML-отчёта для Telegram
│       │       └── main.sh         # Оркестрация: disk check → backup → forget → check → report
│       ├── etc/
│       │   └── backup/
│       │       └── backup.conf     # Основной конфиг (из backup.conf.example)
│       └── secrets/
│           └── .backup.env         # RESTIC_PASSWORD, TG_TOKEN, TG_CHAT_ID
├── etc/
│   ├── init.d/
│   │   └── S99backup               # start | stop | restart | status, PID в /opt/var/run/backup.pid
│   └── logrotate.d/
│       └── backup                  # Ротация /opt/var/log/backup.log
└── var/
    ├── run/
    │   └── backup.pid              # PID процесса бэкапа (при запуске через init.d)
    └── log/
        └── backup.log              # Опционально (BACKUP_LOG_FILE в backup.conf)
```

---

## Конфигурация

### backup.conf (`/opt/usr/local/etc/backup/backup.conf`)

- **BACKUP_SOURCE_DIR** — каталог для бэкапа (обязательно), например `/opt/usr/local`.
- **RESTIC_REPOSITORY** — репозиторий (local или SFTP), обязательный.
- **RESTIC_TAGS**, **RESTIC_HOST** — теги и хост снимков.
- **EXTRA_BACKUP_PATHS** — массив дополнительных путей.
- **RESTIC_EXCLUDES** — массив исключений для restic.
- **KEEP_DAILY**, **KEEP_WEEKLY**, **KEEP_MONTHLY** — политика забывания снимков.
- **BACKUP_LOG_FILE** — опционально, например `/opt/var/log/backup.log` (тогда настройте logrotate).
- **BACKUP_DEBUG** — `1` включает уровень DEBUG в логах.

### .backup.env (`/opt/usr/local/secrets/.backup.env`)

- **RESTIC_PASSWORD** — пароль репозитория.
- **TG_TOKEN**, **TG_CHAT_ID** — для Telegram-уведомлений (опционально).

---

## Логирование

- Сообщения идут в syslog через **logger** с тегом `backup` и приоритетами:  
  INFO → `user.info`, WARN → `user.warning`, ERROR → `user.err`, DEBUG → `user.debug`.
- Объёмный вывод restic (backup/forget/check) передаётся в logger **одним пайпом** (без вызова logger на каждую строку), чтобы не перегружать буфер.
- Если задан **BACKUP_LOG_FILE**, строки дублируются в файл (и в logger). Ротация — через `logrotate` (файл `opt/etc/logrotate.d/backup`).

Просмотр логов: `logread | grep backup` или просмотр файла `/opt/var/log/backup.log` при включённой записи в файл.

---

## Запуск

### Вручную

```bash
/opt/usr/local/bin/backup.sh
```

Если вы **не** использовали `install.sh`, добавьте путь вручную в `PATH`, например в `~/.profile` или `/opt/etc/profile`:

```bash
export PATH="/opt/usr/local/bin:$PATH"
```

### Через init.d (SysVinit)

```bash
/opt/etc/init.d/S99backup start   # Запуск в фоне, PID в /opt/var/run/backup.pid
/opt/etc/init.d/S99backup stop
/opt/etc/init.d/S99backup restart
/opt/etc/init.d/S99backup status
```

### По расписанию (cron)

```bash
0 4 * * * /opt/usr/local/bin/backup.sh
```

Убедитесь, что в cron доступны `PATH` и при необходимости переменные из `.backup.env` (скрипт сам подгружает конфиг и секреты).

---

## Безопасность

- Файлы **\*.env**, **\*.conf** в **.gitignore**. В репозитории только **backup.conf.example** и примеры. Не коммитьте рабочие конфиги и секреты.

---

## Лицензия

См. [LICENSE](LICENSE).
