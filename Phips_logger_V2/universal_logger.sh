#!/bin/bash

#########################################################
# PHIPS UNIVERSAL LOGGER
# Version: 2025.03.16
#########################################################

# Chemin du fichier de configuration
DEFAULT_CONFIG_FILE="/etc/phips_logger/logger_config.cfg"

# Charger la configuration si spécifiée
CONFIG_FILE=${LOGGER_CONFIG_FILE:-$DEFAULT_CONFIG_FILE}
if [ -f "$CONFIG_FILE" ]; then
    source "$CONFIG_FILE"
else
    # Permet au script de fonctionner même sans fichier de configuration
    echo "Note: Fichier de configuration non trouvé: $CONFIG_FILE - Utilisation des valeurs par défaut" >&2
fi

# Définir les paramètres avec des valeurs par défaut si non définies
LOG_DIR="${LOG_DIR:-/var/log/phips_logger}"
LOG_PREFIX="${LOG_PREFIX:-phips}"
LOG_LEVEL="${LOG_LEVEL:-INFO}"
USE_SYSLOG="${USE_SYSLOG:-false}"
ENABLE_NOTIFICATIONS="${ENABLE_NOTIFICATIONS:-false}"
NOTIFICATION_LEVEL="${NOTIFICATION_LEVEL:-WARNING}"
TELEGRAM_BOT_TOKEN="${TELEGRAM_BOT_TOKEN:-}"
TELEGRAM_CHAT_ID="${TELEGRAM_CHAT_ID:-}"
HOSTNAME="${HOSTNAME:-$(hostname)}"
LOG_FILENAME="${LOG_FILENAME:-}"  # Nouveau: permet de spécifier un nom de fichier personnalisé

# Définition des niveaux de log
declare -A LOG_LEVELS=( 
    ["DEBUG"]=0
    ["INFO"]=1
    ["WARNING"]=2
    ["ERROR"]=3
    ["CRITICAL"]=4
)

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
    local module="${1:-}"
    local log_dir="${LOG_DIR}"
    
    # Si un nom de fichier personnalisé est défini, l'utiliser
    if [[ -n "${LOG_FILENAME}" ]]; then
        echo "${log_dir}/${LOG_FILENAME}_$(date +%Y-%m-%d).log"
        return
    fi
    
    # Si un module est fourni, l'utiliser comme nom de fichier
    if [[ -n "${module}" && "${module}" != "logger" && "${module}" != "logger_test" ]]; then
        echo "${log_dir}/${module}_$(date +%Y-%m-%d).log"
        return
    fi
    
    # Sinon, utiliser le préfixe par défaut
    echo "${log_dir}/${LOG_PREFIX}_$(date +%Y-%m-%d).log"
}

# Fonction pour initialiser le fichier de log
init_log_file() {
    local log_file="$1"
    local log_dir="$(dirname "$log_file")"
    
    # Créer le répertoire de log s'il n'existe pas
    if [ ! -d "$log_dir" ]; then
        mkdir -p "$log_dir" 2>/dev/null || {
            echo "Impossible de créer le répertoire de log: $log_dir" >&2
            return 1
        }
        chmod 775 "$log_dir" 2>/dev/null
    fi
    
    # Vérifier si on peut écrire dans le fichier
    if [ -f "$log_file" ] && [ -w "$log_file" ]; then
        return 0
    fi
    
    # Si le fichier n'existe pas, essayer de le créer
    if [ ! -f "$log_file" ]; then
        touch "$log_file" 2>/dev/null || {
            echo "Impossible de créer le fichier de log: $log_file" >&2
            return 1
        }
        chmod 664 "$log_file" 2>/dev/null
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
    if [[ -z "$TELEGRAM_BOT_TOKEN" || -z "$TELEGRAM_CHAT_ID" ]]; then
        echo "Configuration Telegram incomplète pour les notifications" >&2
        return 1
    fi
    
    # Préparer le message
    local formatted_message="🔔 *Notification ${LOG_PREFIX}*%0A"
    formatted_message+="📍 *Host:* \`${HOSTNAME}\`%0A"
    formatted_message+="🔰 *Level:* \`${level}\`%0A"
    formatted_message+="🔧 *Component:* \`${component}\`%0A"
    formatted_message+="📝 *Message:* ${message}"
    
    # Envoyer la notification
    curl -s -X POST \
        "https://api.telegram.org/bot${TELEGRAM_BOT_TOKEN}/sendMessage" \
        -d "chat_id=${TELEGRAM_CHAT_ID}" \
        -d "text=${formatted_message}" \
        -d "parse_mode=Markdown" >/dev/null
}

# Fonction pour l'intégration avec syslog
send_to_syslog() {
    local priority="$1"
    local message="$2"
    local tag="$3"
    
    # Vérifier si logger est disponible
    if command -v logger &> /dev/null && [ "${USE_SYSLOG}" = "true" ]; then
        case "$priority" in
            "DEBUG")    logger -p user.debug -t "$tag" "$message" ;;
            "INFO")     logger -p user.info -t "$tag" "$message" ;;
            "WARNING")  logger -p user.warning -t "$tag" "$message" ;;
            "ERROR")    logger -p user.err -t "$tag" "$message" ;;
            "CRITICAL") logger -p user.crit -t "$tag" "$message" ;;
            *)          logger -p user.notice -t "$tag" "$message" ;;
        esac
    fi
}

# Fonction principale de logging
print_log() {
    local level="$1"
    local module="$2"
    local message="$3"
    local display="${4:-true}"  # Afficher dans la console par défaut
    
    # Convertir le niveau en majuscules pour uniformisation
    level=$(echo "$level" | tr '[:lower:]' '[:upper:]')
    
    # Valider le niveau de log
    if ! validate_log_level "$level"; then
        return 0
    fi
    
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    local log_entry="${timestamp} [${level}] [${module}] [${HOSTNAME}] ${message}"
    
    # Afficher le message dans la console si demandé
    if [ "$display" = "true" ]; then
        case "$level" in
            "DEBUG")    echo -e "\e[34m${message}\e[0m" ;;  # Bleu
            "INFO")     echo -e "\e[32m${message}\e[0m" ;;  # Vert
            "WARNING")  echo -e "\e[33m${message}\e[0m" ;;  # Jaune
            "ERROR")    echo -e "\e[31m${message}\e[0m" ;;  # Rouge
            "CRITICAL") echo -e "\e[1;31m${message}\e[0m" ;; # Rouge gras
            *)          echo "$message" ;;
        esac
    fi
    
    # Envoyer au syslog si configuré
    send_to_syslog "$level" "$message" "${LOG_PREFIX}-${module}"
    
    # Envoyer une notification Telegram si nécessaire
    if [ "${ENABLE_NOTIFICATIONS}" = "true" ]; then
        send_telegram_notification "$message" "$level" "$module"
    fi
    
    # Obtenir le fichier de log et l'initialiser
    local log_file=$(get_log_file "$module")
    init_log_file "$log_file"
    
    # Essayer d'écrire dans le fichier
    if echo "$log_entry" >> "$log_file" 2>/dev/null; then
        return 0
    fi
    
    # Si l'écriture échoue, utiliser le fallback
    echo "$log_entry" >> "/tmp/${module:-$LOG_PREFIX}_$(date +%Y-%m-%d).log"
    echo "Utilisation du fichier de fallback: /tmp/${module:-$LOG_PREFIX}_$(date +%Y-%m-%d).log" >&2
    return 1
}

# Fonction pour rotation des logs
rotate_logs() {
    local max_days="${1:-7}"  # Nombre de jours à conserver par défaut
    local log_pattern="${2:-*.log}"  # Pattern des fichiers à traiter
    
    find "$LOG_DIR" -name "$log_pattern" -type f -mtime +$max_days -delete 2>/dev/null
    if [ $? -eq 0 ]; then
        print_log "INFO" "logger" "Rotation des logs: suppression des fichiers de plus de $max_days jours" "false"
        return 0
    else
        print_log "ERROR" "logger" "Erreur lors de la rotation des logs" "false"
        return 1
    fi
}

# Test d'installation du logger
test_logger() {
    print_log "DEBUG" "logger_test" "Test de message niveau DEBUG"
    print_log "INFO" "logger_test" "Test de message niveau INFO"
    print_log "WARNING" "logger_test" "Test de message niveau WARNING"
    print_log "ERROR" "logger_test" "Test de message niveau ERROR"
    print_log "CRITICAL" "logger_test" "Test de message niveau CRITICAL"
    
    echo "Tests du logger terminés. Vérifier le fichier: $(get_log_file 'logger_test')"
}

# Si ce script est exécuté directement et non importé
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    # Vérifie si c'est un appel pour tester le logger
    if [[ "$1" == "test" ]]; then
        test_logger
    elif [[ "$1" == "rotate" ]]; then
        rotate_logs "$2"
    elif [[ "$1" == "help" ]]; then
        echo "Usage: $(basename $0) [test|rotate|help]"
        echo "  test   : Teste le logger avec différents niveaux de messages"
        echo "  rotate : Effectue une rotation des logs (supprime les anciens)"
        echo "  help   : Affiche cette aide"
    else
        echo "Script de logging universel. Utilisation comme module:"
        echo "source $(basename $0)"
        echo "Pour plus d'options: $(basename $0) help"
    fi
fi