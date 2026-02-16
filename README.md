# Restic Backup for Entware / Keenetic

Набор модульных скриптов для автоматизированного резервного копирования через [Restic](https://restic.net/) на роутерах Keenetic с установленным Entware. Секреты выносятся в `.env`-файлы, уведомления отправляются в Telegram.

---

## Project Overview

Скрипты выполняют:

| Этап | Действие |
|------|----------|
| **1. Disk checkup** | Проверка наличия и валидности репозиториев в `BACKUP_DIR` перед запуском. |
| **2. Backup** | Резервное копирование `/opt/root` в Restic-репозиторий с исключениями (логи, кэш, скрытые каталоги). |
| **3. Cleanup** | Политика хранения: `forget` + `prune` по правилам keep-daily/weekly/monthly для всех репозиториев в `BACKUP_DIR`. |
| **4. Integrity check** | Проверка целостности всех репозиториев в `BACKUP_DIR` через `restic check`. |

При успехе или ошибке в Telegram уходит краткий отчёт (HTML).

---

## Prerequisites

### Пакеты Entware (opkg)

Установите зависимости:

```bash
opkg update
opkg install curl bzip2
```

При использовании удалённого репозитория (SFTP, REST и т.д.) могут понадобиться дополнительные пакеты (например, `openssh-client` для SFTP).

### Restic (ручная установка)

Restic в репозитории Entware может отсутствовать или быть устаревшим. Рекомендуется ставить бинарник вручную:

1. Определите архитектуру роутера:
   ```bash
   uname -m
   ```
   Типичные значения для Keenetic: `aarch64`, `armv7l`, `mips`.

2. Скачайте бинарник с [GitHub Releases](https://github.com/restic/restic/releases) и положите в `PATH` (например, `/opt/bin/restic`):
   ```bash
   # Пример для aarch64
   curl -sSL -o /opt/bin/restic https://github.com/restic/restic/releases/download/v0.16.2/restic_0.16.2_linux_arm64.bz2
   bunzip2 -f /opt/bin/restic.bz2 2>/dev/null || true
   chmod +x /opt/bin/restic
   restic version
   ```

> **Pro-tip:** На слабых роутерах с ограниченной RAM при больших бэкапах рассмотрите создание swap-файла на USB/SD, иначе процесс может быть убит OOM-killer.

---

## Project Structure

```
/opt/root/
├── bin/                    # Точки входа
│   ├── backup              # Основной скрипт бэкапа (4 шага)
│   ├── send                # Отправка сообщений (Telegram)
│   ├── format              # Форматирование текста
│   ├── log                 # Логирование
│   └── import              # Импорт конфигов и библиотек
├── lib/                    # Модульные библиотеки
│   ├── backup/
│   │   ├── disk_checkup.sh # Проверка BACKUP_DIR и репозиториев
│   │   ├── restic_backup.sh
│   │   ├── cleanup.sh      # forget + prune
│   │   ├── integrity_check.sh
│   │   └── parse_log.sh    # Выборка строк из логов restic для отчётов
│   ├── send/
│   │   └── tg/send_html.sh # HTTP-запрос к Telegram Bot API
│   ├── import/             # Загрузка .conf/.env и подключаемых скриптов
│   ├── format/
│   ├── log/
│   └── shared/             # check_var и т.д.
├── etc/                    # Конфигурация (не коммитится)
│   ├── backup/
│   │   ├── backup.conf
│   │   └── backup.conf.example
│   └── restic/
│       ├── restic.conf
│       └── restic.conf.example
├── secrets/                # Секреты (не коммитятся)
│   ├── .tg.env             # TOKEN, CHAT_ID для Telegram
│   └── backup/
│       └── .restic.env     # RESTIC_PASSWORD и др.
├── var/log/                # Логи запусков бэкапа
└── README.md
```

Конфиги и секреты подгружаются через `import -f <file>`. Библиотеки подключаются через `import -l <dir>`.

---

## Setup & Configuration

### 1. Каталог секретов и конфигов

- Создайте каталоги и скопируйте примеры:
  ```bash
  mkdir -p /opt/root/secrets/backup
  mkdir -p /opt/root/etc/backup /opt/root/etc/restic
  cp /opt/root/etc/backup/backup.conf.example /opt/root/etc/backup/backup.conf
  cp /opt/root/etc/restic/restic.conf.example /opt/root/etc/restic/restic.conf
  ```
- Создайте файлы секретов (имена как в примерах ниже), без коммита в git.

### 2. Обязательные переменные

| Файл | Переменные | Описание |
|------|------------|----------|
| **etc/backup/backup.conf** | `BACKUP_DIR`, `LOG_DIR` | Каталог с поддиректориями-репозиториями и каталог логов. |
| **etc/restic/restic.conf** | `KEEP_DAILY`, `KEEP_WEEKLY`, `KEEP_MONTHLY`, `RESTIC_REPOSITORY`, `TAGS` | Политика хранения и путь репозитория для бэкапа, теги снапшотов. |
| **secrets/backup/.restic.env** | `RESTIC_PASSWORD` (и при необходимости `RESTIC_REPOSITORY`) | Пароль репозитория. |
| **secrets/.tg.env** | `TOKEN`, `CHAT_ID` | Токен бота и ID чата для Telegram. |

В `.example`-файлах указаны имена переменных; значения задаются только в рабочих `backup.conf`, `restic.conf` и в секретных `.env`.

### 3. Структура BACKUP_DIR

- `BACKUP_DIR` — каталог, в котором лежат **поддиректории** — каждый подкаталог считается путём к одному Restic-репозиторию.
- В каждой такой поддиректории должен быть файл **config** (маркер валидного репозитория). Каталог `lost+found` игнорируется.
- Файлы или симлинки в `BACKUP_DIR` считаются ошибкой; при наличии невалидных записей или отсутствии ни одного репозитория **disk_checkup** завершается с ошибкой и бэкап не стартует.
- **Backup** пишет только в репозиторий из `RESTIC_REPOSITORY` (в `restic.conf`). **Cleanup** и **integrity check** выполняются для каждого репозитория в `BACKUP_DIR`. Обычно `RESTIC_REPOSITORY` указывает на один из каталогов внутри `BACKUP_DIR` (например, `BACKUP_DIR=/opt/backup`, `RESTIC_REPOSITORY=/opt/backup/main`).

---

## Usage

### Запуск вручную

Из корня проекта (или с путём к скрипту):

```bash
/opt/root/bin/backup
```

Скрипт по очереди: проверяет диск → делает backup → prune → integrity check. Лог пишется в `$LOG_DIR/backup_YYYYMMDD_HHMMSS.log`.

### Cron (регулярный запуск)

Добавьте задачу в crontab (например, раз в день в 4:00):

```bash
crontab -e
```

```cron
0 4 * * * /opt/root/bin/backup
```

Убедитесь, что в cron-окружении доступны `PATH` и при необходимости переменные, требуемые для Restic (если не заданы в `.restic.env`).

### disk_checkup

- Читает `backup.conf`, получает `BACKUP_DIR`.
- Обходит `$BACKUP_DIR/*`: только директории с файлом `config` считаются репозиториями; файлы и прочие типы записей — ошибка.
- Если есть невалидные записи или ни одного репозитория — возврат с ошибкой, бэкап не выполняется, в Telegram уходит сообщение о провале checkup.

### parse_log

Вспомогательная функция для коротких отчётов в Telegram: фильтрует вывод Restic по типу операции:

| Тип | Назначение |
|-----|------------|
| `--backup` | Строки про Files/Dirs/Added to the repository. |
| `--cleanup` | Строки про keep N snapshots, removed, remaining, frees. |
| `--checkup` | Строки про snapshots и no errors were found. |

Используется в `restic_backup.sh`, `cleanup.sh`, `integrity_check.sh` для формирования блока «Stats» в сообщении.

---

## Telegram Integration

1. Создайте бота через [@BotFather](https://t.me/BotFather), получите **токен**.
2. Узнайте **chat_id** (личный или группы), например через [@userinfobot](https://t.me/userinfobot) или запрос к API после отправки боту сообщения:
   ```bash
   curl -s "https://api.telegram.org/bot<TOKEN>/getUpdates"
   ```
3. Создайте `/opt/root/secrets/.tg.env`:
   ```bash
   TOKEN=123456:ABC-DEF...
   CHAT_ID=-1001234567890
   ```
4. Скрипт `send -t "<message>"` подгружает `secrets/.tg.env` и вызывает Telegram Bot API (HTML). Отправка используется из `bin/backup` для итогового отчёта.

> **Pro-tip:** На роутере без доступа в интернет в момент бэкапа отправка в Telegram не сработает; скрипт при этом не падает, основная логика бэкапа выполняется по логам.

---

## Security

- Каталог **secrets/** и файлы **\*.env**, **\*.env.\*** добавлены в **.gitignore** — в репозиторий не должны попадать пароли, токены и chat_id.
- Конфиги **\*.conf** также в .gitignore; в репозитории хранятся только **\*.conf.example** с перечнем переменных без значений.
- Не коммитьте рабочие `backup.conf`, `restic.conf` и любые файлы из `secrets/`. Проверяйте `git status` перед push.

---

## Pro-tips (Keenetic / Entware)

| Проблема | Рекомендация |
|----------|--------------|
| Мало RAM, процесс убит | Уменьшите объём бэкапа (исключения в `restic backup`), поставьте swap на USB/SD или запускайте бэкап в часы минимальной нагрузки. |
| Медленный или нестабильный диск | Храните репозиторий на внешнем USB/SD с нормальной файловой системой (ext4 и т.п.), не в tmpfs. |
| Cron не видит PATH | В crontab задайте явно: `PATH=/opt/bin:/opt/sbin:/bin:/usr/bin` или вызывайте скрипт через `env -i PATH=... /opt/root/bin/backup`. |
| Нет Restic в opkg | Используйте ручную установку бинарника под вашу архитектуру (см. Prerequisites). |

---

## License

См. файл [LICENSE](LICENSE) в корне проекта.
