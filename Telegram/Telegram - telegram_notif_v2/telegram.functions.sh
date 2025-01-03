#!/bin/bash

# Charger les identifiants depuis le fichier de configuration
source /etc/telegram/notif_connexion/telegram.config

API="https://api.telegram.org/bot${TELEGRAM_BOT_TOKEN}"

function telegram_text_send() {
    local API="$API"
    local CHATID="$TELEGRAM_CHAT_ID"
    local PARSE_MODE="markdown"
    local TEXT="$1"
    local ENDPOINT="sendMessage"

    if [ -z "$CHATID" ] || [ -z "$TEXT" ]; then
	echo "---------------------------------------------"
        echo "Erreur : Le chat ID ou le texte est manquant."
	echo "---------------------------------------------"
        return 1
    fi

	curl -s -d "chat_id=${CHATID}&text=${TEXT}&parse_mode=${PARSE_MODE}" ${API}/${ENDPOINT} >/dev/null
}