#!/bin/bash

# A placer dans /usr/local/bin/ftp_video/phips_logger.sh

# Phips
# Version : 2024.03.24 10:50

# Obtenir le nom de l'hôte pour l'identification du device
HOSTNAME=$(hostname)

# Fonction pour obtenir le nom du fichier de log du jour
get_log_file() {
    echo "/var/log/ftp_telegram/ftp_telegram_$(date +%Y-%m-%d).log"
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
        chmod 664 "$log_file" 2>/dev/null || return 1
    fi
    
    # Vérifier si on peut écrire dans le fichier
    if [ ! -w "$log_file" ]; then
        return 1
    fi
    
    return 0
}

# Fonction principale de logging
print_log() {
    local level="$1"
    local component="$2"
    local message="$3"
    local timestamp=$(date +"%Y-%m-%d %H:%M:%S")
    local log_file=$(get_log_file)
    local log_entry="${timestamp} [${level}] [${component}] [${HOSTNAME}] ${message}"
    
    # Afficher le message dans la console
    echo "$message"
    
    # Initialiser le fichier de log
    if ! init_log_file "$log_file"; then
        # Si échec, utiliser le fallback
        log_file="/tmp/ftp_telegram_$(date +%Y-%m-%d).log"
        init_log_file "$log_file"
    fi
    
    # Écrire dans le log
    echo "$log_entry" >> "$log_file" 2>/dev/null || \
    echo "$log_entry" >> "/tmp/ftp_telegram_$(date +%Y-%m-%d).log"
}
