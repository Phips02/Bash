#!/bin/bash

# Envoyer le message à Telegram
BOT_TOKEN="0000000000:00000000000000000000000000000000000"
CHAT_ID="000000000"
URL="https://api.telegram.org/bot$BOT_TOKEN/sendMessage"

DATE=$(date "+%F %H:%M:%S")
UTILISATEUR=$common_name
temps_en_secondes=$time_duration

if [[ -z "$UTILISATEUR" || -z "$temps_en_secondes" ]]; then
  echo "Erreur : UTILISATEUR ou temps_en_secondes n'est pas défini."
  exit 1
fi

# Calcul des heures, des minutes et des secondes
heures=$((temps_en_secondes / 3600))
minutes=$(( (temps_en_secondes % 3600) / 60 ))
secondes=$((temps_en_secondes % 60))

# Ajout de zéros de remplissage si nécessaire
heures=$(printf "%02d" $heures)
minutes=$(printf "%02d" $minutes)
secondes=$(printf "%02d" $secondes)

MESSAGE="$DATE %0A\
OpenVPN NomDeMonInfra %0A\
Utilisateur déconnecté : $UTILISATEUR %0A\
Durée de la connexion : \`$heures:$minutes:$secondes\` %0A"

# Envoyer une notification via l'API Telegram
curl -s -X POST $URL -d chat_id=$CHAT_ID -d text="$MESSAGE" -d parse_mode="Markdown"
