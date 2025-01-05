#!/bin/bash
# Éviter les doubles notifications
if [ -n "$TELEGRAM_NOTIFICATION_SENT" ]; then
    exit 0
fi
export TELEGRAM_NOTIFICATION_SENT=1

source /etc/telegram/notif_connexion/telegram.config 2>/dev/null
/usr/local/bin/telegram/notif_connexion/telegram.sh "$@" 