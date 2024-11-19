#!/bin/bash

#A placer dans /usr/local/bin/ftp_video/telegram.functions.sh


#Phips
#Version : 2024.11.18 14:00

#L'adresse de la source à changé... 
#Ancienne source : source /etc/telegram/telegram.config
#La nouvelle source n'a pas été testé ...


# Charger les identifiants depuis le fichier de configuration sécurisé
source /etc/telegram/ftp_video/ftp_config.cfg

API="https://api.telegram.org/bot${TELEGRAM_BOT_TOKEN}"

# Fonction pour envoyer un message via Telegram
function telegram_text_send() {
    local API="$API"
    local CHATID="$TELEGRAM_CHAT_ID"
    local PARSE_MODE="$1"
    local TEXT="$2"
    local ENDPOINT="sendMessage"

    if [ -z "$CHATID" ] || [ -z "$TEXT" ]; then
        echo "Erreur : Le chat ID ou le texte est manquant."
        return 1
    fi

    curl -s -d "chat_id=${CHATID}&text=${TEXT}&parse_mode=${PARSE_MODE}" "${API}/${ENDPOINT}" >/dev/null
}
