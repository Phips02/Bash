#!/bin/bash

#-FR---------------------------------------------
#Pour executer automatiquement le script, ajouter le lien du script dans:
#/etc/profile
#Exemple : /home/pivpn/Bureau/telegram/telegram.sh
#------------------------------------------------

#-EN---------------------------------------------
#To automatically launch the script add the script path in:
#/etc/profile
#Example: /home/pi/telegram/telegram.sh
#------------------------------------------------

source /home/pivpn/Bureau/telegram/telegram.credentials.sh
source /home/pivpn/Bureau/telegram/telegram.functions.sh

DATE=$(date "+%F %H:%M:%S")
IP_DEVICE=$(hostname -I | cut -d " " -f1)
MAC_ADDRESS=$(ifconfig | grep ether | cut -d " " -f10)
IP_LOCAL=$(echo $SSH_CLIENT |cut -d " " -f1)
IP_PUBLIC=$(curl -s ipinfo.io/ip)
COUNTRY=$(curl -s ipinfo.io/country)

TEXT="$DATE %0A\
Connection from : %0A\
Local IP : $IP_LOCAL %0A\
Public IP : $IP_PUBLIC %0A\
Country : $COUNTRY %0A\
------------------------------------------------ %0A\
Device : $HOSTNAME %0A\
IP : $IP_DEVICE %0A\
MAC address : $MAC_ADDRESS %0A\
User : $USER"\


telegram_text_send "$API" "$CHATID" "$KEY" "markdown" "$TEXT"
