#!/bin/bash

# A placer dans /usr/local/bin/ftp_video/phips_logger.sh

# Phips
# Version : 2024.03.24 19:00

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
    
    # Créer le dossier si nécessaire
    if ! mkdir -p "$log_dir" 2>/dev/null; then
        return 1
    fi
    
    # Créer le fichier s'il n'existe pas
    if [ ! -f "$log_file" ]; then
        touch "$log_file" 2>/dev/null || return 1
        chmod "${LOG_PERMISSIONS}" "$log_file" 2>/dev/null || return 1
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
    local level="${1^^}"  # Convertir en majuscules
    local component="$2"
    local message="$3"
    
    # Valider le niveau de log
    if ! validate_log_level "$level"; then
        return 0
    fi
    
    local timestamp=$(date +"%Y-%m-%d %H:%M:%S")
    local log_file=$(get_log_file)
    local log_entry="${timestamp} [${level}] [${component}] [${HOSTNAME}] ${message}"
    
    # Afficher le message dans la console
    echo "$message"
    
    # Envoyer une notification si nécessaire
    send_telegram_notification "$message" "$level" "$component"
    
    # Initialiser le fichier de log
    if ! init_log_file "$log_file"; then
        log_file="/tmp/ftp_telegram_$(date +%Y-%m-%d).log"
        print_log "WARNING" "logger" "Utilisation du fichier de fallback: $log_file"
        init_log_file "$log_file"
    fi
    
    # Écrire dans le log
    echo "$log_entry" >> "$log_file" 2>/dev/null || \
    echo "$log_entry" >> "/tmp/ftp_telegram_$(date +%Y-%m-%d).log"
}
