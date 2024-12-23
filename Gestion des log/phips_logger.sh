#!/bin/bash

#A placer dans /usr/local/bin/phips_logger.sh

#Phips
#Version : 2024.03.21 11:31


# Configuration du logger dans /etc/telegram/ftp_video/ftp_config.cfg
#LOGGER_PATH="/usr/local/bin/phips_logger.sh"
#LOG_FILE="/var/log/ftp_telegram/ftp_telegram.log"


# Configuration par défaut
DEFAULT_LOG_FILE="./custom_script.log"
DEFAULT_LOG_LEVEL="INFO"
VALID_LOG_LEVELS=("DEBUG" "INFO" "NOTICE" "WARNING" "ERROR" "CRITICAL")

# Initialisation des variables globales
DEVICE_NAME=$(hostname)

# Fonction pour obtenir le chemin du fichier de log avec la date
get_log_file() {
    local base_log_file="${LOG_FILE:-$DEFAULT_LOG_FILE}"
    local log_dir=$(dirname "$base_log_file")
    local log_name=$(basename "$base_log_file" .log)
    echo "${log_dir}/${log_name}_$(date +%Y-%m-%d).log"
}

# Fonction pour valider le niveau de log
validate_log_level() {
    local level="$1"
    for valid_level in "${VALID_LOG_LEVELS[@]}"; do
        if [[ "$level" == "$valid_level" ]]; then
            return 0
        fi
    done
    return 1
}

# Fonction pour générer un timestamp simplifié
timestamp() {
    date +"%Y-%m-%dT%H:%M:%S.%3N"
}

# Fonction principale de logging
log_message() {
    local level="${1:-$DEFAULT_LOG_LEVEL}"
    local process_name="$2"
    local message="$3"
    local current_log_file=$(get_log_file)

    # Validation des paramètres
    if [[ -z "$process_name" || -z "$message" ]]; then
        echo "Usage: log_message [LEVEL] PROCESS_NAME MESSAGE" >&2
        return 1
    fi

    # Validation du niveau de log
    if ! validate_log_level "$level"; then
        echo "Invalid log level: $level" >&2
        echo "Valid levels: ${VALID_LOG_LEVELS[*]}" >&2
        return 1
    fi

    # Création et écriture du message de log
    local log_entry
    log_entry="$(timestamp) ${DEVICE_NAME} [ ${level} ] ${process_name}: ${message}"

    # Création du répertoire de log si nécessaire
    local log_dir
    log_dir=$(dirname "$current_log_file")
    if [[ ! -d "$log_dir" ]]; then
        if ! mkdir -p "$log_dir" 2>/dev/null; then
            echo "Erreur : Impossible de créer le répertoire de log $log_dir. Vérifiez les permissions." >&2
            # Utiliser un fichier de log par défaut dans /tmp en cas d'échec
            current_log_file="/tmp/phips_logger_$(date +%Y-%m-%d).log"
            echo "Utilisation du fichier de log alternatif : $current_log_file" >&2
        fi
    fi

    # Vérifier si on peut écrire dans le fichier de log
    if ! touch "$current_log_file" 2>/dev/null; then
        echo "Erreur : Impossible d'écrire dans $current_log_file. Vérifiez les permissions." >&2
        # Utiliser un fichier de log par défaut dans /tmp en cas d'échec
        current_log_file="/tmp/phips_logger_$(date +%Y-%m-%d).log"
        echo "Utilisation du fichier de log alternatif : $current_log_file" >&2
    fi

    # Écriture dans le fichier de log
    echo "${log_entry}" >> "${current_log_file}"
}

# Fonctions helper pour différents niveaux de log
log_debug()    { log_message "DEBUG" "$1" "$2"; }
log_info()     { log_message "INFO" "$1" "$2"; }
log_notice()   { log_message "NOTICE" "$1" "$2"; }
log_warning()  { log_message "WARNING" "$1" "$2"; }
log_error()    { log_message "ERROR" "$1" "$2"; }
log_critical() { log_message "CRITICAL" "$1" "$2"; }

# Exemple d'utilisation si le script est exécuté directement
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    log_info "test-script" "Démarrage du script de test"
    log_debug "test-script" "Test de debug"
    log_notice "test-script" "Message important"
    log_warning "test-script" "Attention !"
    log_error "test-script" "Une erreur est survenue"
    log_critical "test-script" "Erreur critique !"
fi
