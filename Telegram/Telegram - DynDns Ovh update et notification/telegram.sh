#!/bin/bash

#-FR---------------------------------------------
#Pour executer automatiquement le script, ajouter le lien du script dans:
#/etc/profile
#Exemple : /usr/local/bin/dyndns/telegram.sh
#------------------------------------------------

source /usr/local/bin/dyndns/telegram.functions.sh

# Récupération des informations système
DATE=$(date "+%F %H:%M:%S")
IP_DEVICE=$(hostname -I | cut -d " " -f1)
MAC_ADDRESS=$(ip link show | grep ether | awk '{print $2}')
IP_LOCAL=$(echo $SSH_CLIENT |cut -d " " -f1)

# Récupération des informations publiques
IPINFO=$(curl -s ipinfo.io)
IP_PUBLIC=$(echo "$IPINFO" | jq -r '.ip')
COUNTRY=$(echo "$IPINFO" | jq -r '.country')

# Construction du message
TEXT="$DATE %0A\
Connection from : %0A\
Local IP : $IP_LOCAL %0A\
Public IP : $IP_PUBLIC %0A\
Country : $COUNTRY %0A\
------------------------------------------------ %0A\
Device : $HOSTNAME %0A\
IP : $IP_DEVICE %0A\
MAC address : $MAC_ADDRESS %0A\
User : $USER"

# Envoi du message Telegram
telegram_text_send "$TEXT"
