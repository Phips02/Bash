#!/bin/bash

#A placer dans /usr/local/bin/ftp_video/phips_logger.sh

#Phips
#Version : 2024.12.26 10:50

# Charger la configuration
if [ -f "/etc/telegram/ftp_video/ftp_config.cfg" ]; then
    source "/etc/telegram/ftp_video/ftp_config.cfg"
else
    echo "Erreur: Fichier de configuration non trouvé"
    exit 1
fi

# Définir le répertoire de log par défaut si non défini
LOG_DIR="${LOG_DIR:-/var/log/ftp_telegram}"

# Obtenir le nom de l'hôte pour l'identification du device
HOSTNAME=$(hostname)

# Définition des niveaux de log
declare -A LOG_LEVELS=( 
    ["DEBUG"]=0
    ["INFO"]=1
    ["WARNING"]=2
    ["ERROR"]=3
    ["CRITICAL"]=4
)

# Niveau minimum de log (configurable)
LOG_LEVEL="${LOG_LEVEL:-INFO}"

# Fonction de validation du niveau de log
validate_log_level() {
    local level="$1"
    if [[ ! "${LOG_LEVELS[$level]}" ]]; then
        echo "Niveau de log invalide: $level" >&2
        return 1
    fi
    
    # Vérifier si le niveau est suffisant pour être loggé
    if [[ "${LOG_LEVELS[$level]}" -lt "${LOG_LEVELS[$LOG_LEVEL]}" ]]; then
        return 1
    fi
    return 0
}

# Fonction pour obtenir le nom du fichier de log du jour
get_log_file() {
    echo "${LOG_DIR}/ftp_telegram_$(date +%Y-%m-%d).log"
}

# Fonction pour initialiser le fichier de log
init_log_file() {
    local log_file="$1"
    local log_dir="$(dirname "$log_file")"
    
    # Vérifier si on peut écrire dans le fichier
    if [ -w "$log_file" ]; then
        return 0
    fi
    
    # Si le fichier n'existe pas, essayer de le créer
    if [ ! -f "$log_file" ]; then
        touch "$log_file" 2>/dev/null || return 1
        chmod 664 "$log_file" 2>/dev/null || return 1
    fi
    
    return 0
}

# Fonction pour envoyer une notification Telegram
send_telegram_notification() {
    local message="$1"
    local level="$2"
    local component="$3"
    
    # Vérifier si les notifications sont activées
    if [[ "${ENABLE_NOTIFICATIONS}" != "true" ]]; then
        return 0
    fi
    
    # Vérifier si le niveau est suffisant pour notifier
    if [[ "${LOG_LEVELS[$level]}" -lt "${LOG_LEVELS[$NOTIFICATION_LEVEL]}" ]]; then
        return 0
    fi
    
    
    # Vérifier si les paramètres Telegram sont définis
    if [[ -z "$TELEGRAM_BOT_TOKEN" || -z "$DEFAULT_TELEGRAM_CHAT_ID" ]]; then
        echo "Configuration Telegram incomplète" >&2
        return 1
    fi
    
    # Préparer le message
    local formatted_message="🔔 *Notification FTP Video*%0A"
    formatted_message+="📍 *Host:* \`${HOSTNAME}\`%0A"
    formatted_message+="🔰 *Level:* \`${level}\`%0A"
    formatted_message+="🔧 *Component:* \`${component}\`%0A"
    formatted_message+="📝 *Message:* ${message}"
    
    # Envoyer la notification
    curl -s -X POST \
        "https://api.telegram.org/bot${TELEGRAM_BOT_TOKEN}/sendMessage" \
        -d "chat_id=${DEFAULT_TELEGRAM_CHAT_ID}" \
        -d "text=${formatted_message}" \
        -d "parse_mode=Markdown" >/dev/null
}

# Fonction principale de logging
print_log() {
    local level="$1"
    local module="$2"
    local message="$3"
    local hostname=$(hostname)
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    
    # Convertir le niveau en majuscules pour uniformisation
    level=$(echo "$level" | tr '[:lower:]' '[:upper:]')
    
    # Formater le message de log
    local log_message="$timestamp [$level] [$module] [$hostname] $message"
    
    # Valider le niveau de log
    if ! validate_log_level "$level"; then
        return 0
    fi
    
    local log_file=$(get_log_file)
    local log_entry="${timestamp} [${level}] [${module}] [${hostname}] ${message}"
    
    # Afficher le message dans la console
    echo "$message"
    
    # Envoyer une notification si nécessaire
    send_telegram_notification "$message" "$level" "$module"
    
    # Essayer d'écrire directement dans le fichier
    if echo "$log_entry" >> "$log_file" 2>/dev/null; then
        return 0
    fi
    
    # Si l'écriture échoue, utiliser le fallback
    echo "$log_entry" >> "/tmp/ftp_telegram_$(date +%Y-%m-%d).log"
    echo "Utilisation du fichier de fallback: /tmp/ftp_telegram_$(date +%Y-%m-%d).log"
}
