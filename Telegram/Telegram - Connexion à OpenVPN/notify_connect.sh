#!/bin/bash

# Paramètres de notification
BOT_TOKEN="0000000000:00000000000000000000000000000000000"
CHAT_ID="000000000"

DATE=$(date "+%F %H:%M:%S")
UTILISATEUR=$common_name
IP_PUBLIC=$(echo $trusted_ip)

if [[ -z "$UTILISATEUR" || -z "$IP_PUBLIC" ]]; then
  echo "Erreur : UTILISATEUR ou IP_PUBLIC n'est pas défini."
  exit 1
fi

MESSAGE="$DATE %0A\
OpenVPN NomDeMonInfra %0A\
Utilisateur connecté : $UTILISATEUR %0A\
Public IP : $IP_PUBLIC %0A"

# Envoyer une notification via l'API Telegram
curl -s -X POST "https://api.telegram.org/bot$BOT_TOKEN/sendMessage" -d chat_id=$CHAT_ID -d text="$MESSAGE"
