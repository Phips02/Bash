#!/bin/bash

#A placer dans /usr/local/bin/ftp_video/telegram.functions.sh

#Phips
#Version : 2024.12.22 13:41



# Charger les identifiants depuis le fichier de configuration sécurisé
source /etc/telegram/ftp_video/ftp_config.cfg

API="https://api.telegram.org/bot${TELEGRAM_BOT_TOKEN}"

# Ajouter une vérification du token
if [ -z "$TELEGRAM_BOT_TOKEN" ]; then
    echo "Erreur: TELEGRAM_BOT_TOKEN non défini"
    exit 1
fi

# Ajouter une fonction de validation du token
function validate_telegram_token() {
    local response
    response=$(curl -s "${API}/getMe")
    if ! echo "$response" | grep -q '"ok":true'; then
        echo "Erreur: Token Telegram invalide"
        return 1
    fi
    return 0
}

# Ajouter la validation au début du script
validate_telegram_token || exit 1

# Fonction pour envoyer un message via Telegram
function telegram_text_send() {
    local API="$API"
    local CHATID="$TELEGRAM_CHAT_ID"
    local PARSE_MODE="$1"
    local TEXT="$2"
    local ENDPOINT="sendMessage"
    local RESPONSE

    # Vérification des paramètres
    if [ -z "$PARSE_MODE" ]; then
        PARSE_MODE="HTML"  # Mode par défaut
    fi

    if [ -z "$CHATID" ] || [ -z "$TEXT" ]; then
        echo "Erreur : Le chat ID ou le texte est manquant."
        return 1
    fi

    # Ajout de la gestion des erreurs pour curl
    RESPONSE=$(curl -s -d "chat_id=${CHATID}&text=${TEXT}&parse_mode=${PARSE_MODE}" "${API}/${ENDPOINT}")
    if ! echo "$RESPONSE" | grep -q '"ok":true'; then
        echo "Erreur lors de l'envoi du message: $RESPONSE"
        return 1
    fi
}
