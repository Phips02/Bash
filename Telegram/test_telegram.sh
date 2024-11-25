#!/bin/bash

#Phips
#Version : 2024.11.25 21:22

# Credentials Telegram
TELEGRAM_BOT_TOKEN="1234567890:ABCDEFGHIJKLMNOpqrstuvwxYZ1234567890"
TELEGRAM_CHAT_ID="-987654321"

API="https://api.telegram.org/bot${TELEGRAM_BOT_TOKEN}"

# Message de test
TEXT="Test de notification Telegram : Bot opérationnel avec succès !"
ENDPOINT="sendMessage"

# Envoi du message
curl -s -d "chat_id=${TELEGRAM_CHAT_ID}&text=${TEXT}" ${API}/${ENDPOINT} >/dev/null

if [ $? -eq 0 ]; then
    echo "Message de test envoyé avec succès."
else
    echo "Échec de l'envoi du message de test."
fi
