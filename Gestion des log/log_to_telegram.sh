#!/bin/bash

#A placer dans /usr/local/bin/log_to_telegram.sh

#Phips
#Version : 2024.12.22 21:15

#--------------------------------------------------------------------
# Méthode 1 - Notification des ERROR et CRITICAL uniquement
# /usr/local/bin/log_to_telegram.sh

# Méthode 2 - Notification à partir du niveau WARNING
# NOTIFY_MIN_LEVEL=WARNING /usr/local/bin/log_to_telegram.sh
#--------------------------------------------------------------------



# Chargement de la configuration
CONFIG_FILE="/etc/telegram/ftp_video/ftp_config.cfg"
if [[ ! -f "$CONFIG_FILE" ]]; then
    echo "Erreur: Fichier de configuration non trouvé: $CONFIG_FILE"
    exit 1
fi
source "$CONFIG_FILE"

# Définition des niveaux de log et leur priorité
declare -A LOG_LEVELS=(
    ["DEBUG"]=0
    ["INFO"]=1
    ["NOTICE"]=2
    ["WARNING"]=3
    ["ERROR"]=4
    ["CRITICAL"]=5
)

# Niveau de log minimum pour déclencher une notification (par défaut: ERROR)
NOTIFY_MIN_LEVEL="${NOTIFY_MIN_LEVEL:-ERROR}"

# Validation du niveau de notification
if [[ ! ${LOG_LEVELS[$NOTIFY_MIN_LEVEL]+_} ]]; then
    echo "Niveau de log invalide: $NOTIFY_MIN_LEVEL"
    echo "Niveaux valides: ${!LOG_LEVELS[@]}"
    exit 1
fi

# Fonction pour vérifier si un niveau de log doit déclencher une notification
should_notify() {
    local current_level="$1"
    [[ ${LOG_LEVELS[$current_level]} -ge ${LOG_LEVELS[$NOTIFY_MIN_LEVEL]} ]]
}

# Fonction pour envoyer un message via Telegram
send_telegram_message() {
    local message="$1"
    curl -s -X POST "https://api.telegram.org/bot${TELEGRAM_BOT_TOKEN}/sendMessage" \
        -d "chat_id=${TELEGRAM_CHAT_ID}" \
        -d "text=${message}" \
        -d "parse_mode=HTML"
}

# Fonction pour surveiller les nouveaux logs
monitor_logs() {
    local log_file=$(dirname "$LOG_FILE")/$(basename "$LOG_FILE" .log)_$(date +%Y-%m-%d).log
    
    if [[ ! -f "$log_file" ]]; then
        echo "Erreur: Fichier de log non trouvé: $log_file"
        exit 1
    }

    echo "Surveillance des logs pour les niveaux >= $NOTIFY_MIN_LEVEL"
    
    # Utiliser tail -F pour suivre le fichier même s'il est rotation
    tail -F "$log_file" | while read line; do
        # Extraire le niveau de log de la ligne
        if [[ $line =~ \[(.*?)\] ]]; then
            level="${BASH_REMATCH[1]}"
            if should_notify "$level"; then
                # Formater le message pour Telegram
                message="🚨 <b>Alerte Log (${level})</b>\n\n<code>${line}</code>"
                send_telegram_message "$message"
            fi
        fi
    done
}

# Démarrer la surveillance
monitor_logs
