#!/bin/sh
# Низкоуровневая отправка HTTP‑запроса в Telegram.
# Ожидает, что TOKEN и CHAT_ID уже выставлены в окружении.
send_html() {
    curl -sS -X POST "https://api.telegram.org/bot$TOKEN/sendMessage" \
        -d chat_id="$CHAT_ID" \
        -d parse_mode="HTML" \
        -d text="$1" > /dev/null
}
