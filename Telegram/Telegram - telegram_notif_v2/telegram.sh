#!/bin/bash

#-FR---------------------------------------------
#Pour executer automatiquement le script, ajouter le lien du script dans:
#/etc/profile
#Exemple : /usr/local/bin/notif_connexion/telegram.sh
#------------------------------------------------

# Vérification des dépendances
if ! command -v jq &> /dev/null; then
    echo "Erreur : jq n'est pas installé"
    exit 1
fi

if ! command -v curl &> /dev/null; then
    echo "Erreur : curl n'est pas installé"
    exit 1
fi

source /usr/local/bin/telegram/notif_connexion/telegram.functions.sh

# Fonction améliorée pour détecter l'IP source
get_source_ip() {
    # Pour les connexions SSH directes
    if [ -n "$SSH_CONNECTION" ]; then
        echo "$SSH_CONNECTION" | awk '{print $1}'
        return
    fi

    # Pour les sessions su/sudo, trouver la session SSH parente
    if [ -z "$SSH_CONNECTION" ] && [ "$TERM" != "unknown" ]; then
        local ppid=$PPID
        while [ "$ppid" -ne 1 ]; do
            local parent_cmd=$(ps -o cmd= -p $ppid)
            if [[ "$parent_cmd" == *"sshd"* ]]; then
                local parent_ssh_ip=$(ss -tnp 2>/dev/null | grep "$ppid" | awk '{print $3}' | cut -d':' -f1)
                if [ -n "$parent_ssh_ip" ]; then
                    echo "$parent_ssh_ip"
                    return
                fi
            fi
            ppid=$(ps -o ppid= -p $ppid)
        done
    fi

    echo "Indisponible"
}

# Récupération des informations système
DATE=$(date "+%F %H:%M:%S")
IP_DEVICE=$(hostname -I | cut -d " " -f1)
MAC_ADDRESS=$(ip link show | grep ether | awk '{print $2}')
IP_LOCAL=$(get_source_ip)

# Récupération des informations publiques
IPINFO=$(curl -s ipinfo.io)
IP_PUBLIC=$(echo "$IPINFO" | jq -r '.ip')
COUNTRY=$(echo "$IPINFO" | jq -r '.country')

# Validation des informations récupérées
if [ -z "$IP_PUBLIC" ]; then
    IP_PUBLIC="Indisponible"
fi

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