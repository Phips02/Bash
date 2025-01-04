#!/bin/bash

# Script de notification Telegram pour les connexions SSH et su
# Version 3.0

# Fonction pour vérifier la configuration
check_config() {
    local config="/etc/telegram/notif_connexion/telegram.config"
    
    # Vérification de l'existence du fichier
    if [ ! -f "$config" ]; then
        echo "Erreur : Le fichier de configuration n'existe pas : $config" >/dev/null
        return 1
    fi

    # Vérification des permissions de lecture
    if [ ! -r "$config" ]; then
        echo "Erreur : Le fichier de configuration n'est pas lisible : $config" >/dev/null
        return 1
    fi

    # Chargement de la configuration
    source "$config"

    # Vérification des variables requises
    local required_vars=("TELEGRAM_BOT_TOKEN" "TELEGRAM_CHAT_ID" "BASE_DIR" "CONFIG_DIR" "SCRIPT_PATH" "CONFIG_PATH")
    for var in "${required_vars[@]}"; do
        if [ -z "${!var}" ]; then
            echo "Erreur : Variable $var non définie dans $config" >/dev/null
            return 1
        fi
    done

    return 0
}

# Vérification de la configuration avant de continuer
if ! check_config; then
    exit 1
fi

# Exécution en arrière-plan si ce n'est pas déjà le cas
if [ "$1" != "background" ]; then
    $0 background & disown
    exit 0
fi

# Vérification des dépendances
if ! command -v jq &> /dev/null; then
    echo "Erreur : jq n'est pas installé" >/dev/null
    exit 1
fi

if ! command -v curl &> /dev/null; then
    echo "Erreur : curl n'est pas installé" >/dev/null
    exit 1
fi

# Configuration de l'API Telegram
API="https://api.telegram.org/bot${TELEGRAM_BOT_TOKEN}"

# Fonction d'envoi de message Telegram
function telegram_text_send() {
    local TEXT="$1"
    if [[ -z "$TELEGRAM_CHAT_ID" || -z "$TEXT" ]]; then
        echo "Erreur : Chat ID ou texte manquant."
        return 1
    fi
    curl -s -d "chat_id=${TELEGRAM_CHAT_ID}&text=${TEXT}&parse_mode=markdown" "${API}/sendMessage" >/dev/null
}

# Fonction pour détecter l'IP source
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
            # Vérification que ppid est bien un entier avant de l'utiliser
            if [[ "$ppid" =~ ^[0-9]+$ ]]; then
                ppid=$(ps -o ppid= -p $ppid)
            else
                echo "Erreur : PPID non valide"
                break
            fi
        done
    fi

    echo "Indisponible"
}

# Détection du type de connexion
get_connection_type() {
    if [ -n "$SSH_CONNECTION" ]; then
        echo "SSH"
    elif [ -n "$PAM_TYPE" ]; then
        echo "su/sudo"
    else
        echo "Local"
    fi
}

# Récupération des informations système
DATE=$(date "+%F %H:%M:%S")
IP_DEVICE=$(hostname -I | cut -d " " -f1)
MAC_ADDRESS=$(ip link show | grep ether | awk '{print $2}')
IP_LOCAL=$(get_source_ip)
CONNECTION_TYPE=$(get_connection_type)

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
------------------------------------------------ %0A\
Type de connexion : $CONNECTION_TYPE %0A\
Utilisateur : $USER %0A\
------------------------------------------------ %0A\
Appareil : $HOSTNAME %0A\
IP Locale : $IP_DEVICE %0A\
Adresse MAC : $MAC_ADDRESS %0A\
------------------------------------------------ %0A\
Connexion depuis : %0A\
IP Source : $IP_LOCAL %0A\
IP Publique : $IP_PUBLIC %0A\
Pays : $COUNTRY"

# Envoi du message Telegram
telegram_text_send "$TEXT"