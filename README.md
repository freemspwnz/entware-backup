# Restic Backup для Entware / Keenetic

Модульный бэкап через [Restic](https://restic.net/) для роутеров Keenetic с Entware. Логирование в файл (по умолчанию `/opt/var/log/backup.log`) с ротацией через logrotate, один конфиг `backup.conf`. Уведомления в Telegram.

---

## Обзор

Скрипт рассчитан на запуск **на роутере с Entware** и выполняет обслуживание Restic‑репозиториев на подключённом диске:

| Этап | Действие |
|------|----------|
| **1. Disk checkup** | Проверка каталога-источника `BACKUP_SOURCE_DIR`: существование, читаемость, наличие поддиректорий (что именно бэкапить — задаётся пользователем). |
| **2. Backup** | Бэкап содержимого `BACKUP_SOURCE_DIR` (и `EXTRA_BACKUP_PATHS`) в репозиторий `RESTIC_REPOSITORY`. |
| **3. Cleanup** | Очистка старых снимков (`forget` + `prune`, keep-daily/weekly/monthly) для **всех** Restic‑репозиториев в каталоге, в котором лежит `RESTIC_REPOSITORY`. |
| **4. Integrity check** | `restic check` для **всех** репозиториев в этом каталоге. |

Очистка и проверка выполняются только для репозиториев в каталоге `dirname(RESTIC_REPOSITORY)`.

При успехе или ошибке в Telegram уходит краткий HTML-отчёт. Одновременно может выполняться только один экземпляр бэкапа: повторный запуск (например, из cron и init.d в одно время) завершается без отправки отчёта.

---

## Требования

- **Bash**: `/opt/bin/bash` (Entware).
- **Пакеты**: `curl`, `logrotate`, `coreutils-install` (отсутствуют в стандартном Entware); при наличии удалённых хостов, делающих бекапы по SFTP — `openssh-sftp-server`.
- **Restic**: как правило, ручная установка бинарника в `/opt/bin/restic` (см. документацию Restic / релизы GitHub).

---

## Установка

Проект изолирован от opkg и стандартных путей Entware: всё своё он кладёт в `/opt/usr/local/` и не трогает `/opt/bin`, `/opt/lib` и т.п.

На устройстве с Entware (из корня репозитория):

```bash
/opt/bin/bash install.sh
```

Скрипт создаёт каталоги в `/opt/usr/local`, копирует `bin/backup.sh`, файлы из `lib/` и `lib/backup/`, пример конфига в `/opt/usr/local/etc/backup/backup.conf`, init.d-скрипт и конфиг logrotate. Также создаёт при необходимости задачу `/opt/etc/cron.daily/logrotate` и файл расписания бэкапа `/opt/etc/cron.d/backup` (запуск в 05:00). Существующие `backup.conf` и файл секретов не перезаписываются.

---

## Структура после установки

```
/opt/
├── usr/
│   └── local/
│       ├── bin/
│       │   └── backup.sh          # Точка входа (#!/opt/bin/bash)
│       ├── lib/
│       │   ├── logger.sh          # Запись в LOG_FILE (printf), уровни INFO/WARN/ERROR
│       │   ├── telegram.sh        # Telegram Bot API
│       │   └── backup/
│       │       ├── config.sh      # Загрузка backup.conf и .backup.env
│       │       ├── disk_check.sh  # Проверка BACKUP_SOURCE_DIR
│       │       ├── restic.sh      # backup, forget, check (вывод во временный буфер для stats/Telegram)
│       │       ├── report.sh      # Сборка HTML-отчёта для Telegram
│       │       └── main.sh        # Оркестрация: disk check → backup → forget → check → report
│       ├── etc/
│       │   └── backup/
│       │       └── backup.conf    # Основной конфиг (из backup.conf.example)
│       └── secrets/
│           └── .backup.env        # RESTIC_PASSWORD, TG_TOKEN, TG_CHAT_ID
├── etc/
│   ├── init.d/
│   │   └── S99backup              # start | stop | restart | status, PID в /opt/var/run/backup.pid
│   └── logrotate.d/
│       └── backup                 # Ротация /opt/var/log/backup.log
└── var/
    ├── run/
    │   ├── backup.pid             # PID процесса бэкапа (при запуске через init.d)
    │   └── backup.lock.d/         # Lock-каталог: только один экземпляр backup_run
    └── log/
        └── backup.log             # LOG_FILE в backup.conf
```

---

## Конфигурация

### backup.conf (`/opt/usr/local/etc/backup/backup.conf`)

- **BACKUP_SOURCE_DIR** — каталог для бэкапа (обязательно), например `/opt/usr/local`.
- **RESTIC_REPOSITORY** — локальный путь к основному Restic‑репозиторию на роутере, например `/opt/var/backup/repo-main`. Очистка и проверка будут выполняться для **всех** подкаталогов в `dirname(RESTIC_REPOSITORY)`.
- **RESTIC_BIN** — путь к бинарнику restic (по умолчанию `restic` из PATH).
- **RESTIC_TAGS**, **RESTIC_HOST** — теги и хост снимков.
- **EXTRA_BACKUP_PATHS** — массив дополнительных путей.
- **RESTIC_EXCLUDES** — массив исключений для restic.
- **KEEP_DAILY**, **KEEP_WEEKLY**, **KEEP_MONTHLY** — политика забывания снимков.
- **LOG_FILE** — `/opt/var/log/backup.log` (тогда настройте logrotate).
- **DEBUG_FLG** — `1` включает уровень DEBUG в логах.

### .backup.env (`/opt/usr/local/secrets/.backup.env`)

- **RESTIC_PASSWORD** — пароль репозитория.
- **TG_TOKEN**, **TG_CHAT_ID** — для Telegram-уведомлений (опционально).

---

## Логирование

- Все сообщения пишутся **только в файл** (по умолчанию `/opt/var/log/backup.log`) через `printf`, без использования системного `logger`.
- Формат строки: `YYYY-MM-DD HH:MM:SS [LEVEL] message`.
- «Сырой» вывод restic (backup/forget/check) **не** пишется в лог‑файл, чтобы не раздувать его размер.
- При ошибке tail‑часть вывода restic (последние ~50 строк) добавляется в Telegram‑отчёт в блоке `<pre>…</pre>`.
- Ротация файла `/opt/var/log/backup.log` настраивается через `logrotate` (файл `/opt/etc/logrotate.d/backup`).

Просмотр логов: `cat /opt/var/log/backup.log` или через любой текстовый просмотрщик.

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

В каталог `/opt/etc/cron.d/` `install.sh` создаёт файл `backup` с расписанием запуска в 05:00:

```bash
0 5 * * * root /opt/bin/bash /opt/usr/local/bin/backup.sh
```

Если файл уже есть и в нём есть строка с запуском `backup.sh`, расписание не меняется. Если файла нет или в нём нет этой строки — она добавляется.

Скрипт сам подгружает конфиг и секреты из `/opt/usr/local/etc/backup/backup.conf` и `/opt/usr/local/secrets/.backup.env`. Если в одно время запустить бэкап и из cron, и через init.d — выполнится один процесс, второй завершится с записью в лог «Backup already running (lock held), exiting.» и без отправки в Telegram.

---

## Безопасность

- Файлы **\*.env**, **\*.conf** в **.gitignore**. В репозитории только **backup.conf.example** и примеры. Не коммитьте рабочие конфиги и секреты.

---

## Лицензия

См. [LICENSE](LICENSE).
