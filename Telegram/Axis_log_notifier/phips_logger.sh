#!/bin/bash

# Phips - Version : 2024.03.28 11:30

# Charger la configuration
if [ -f "/etc/AxisLogNotifier/config.cfg" ]; then
    source "/etc/AxisLogNotifier/config.cfg"
else
    echo "Erreur: Fichier de configuration non trouvé"
    exit 1
fi

# Définir le répertoire de log par défaut si non défini
LOG_DIR="${LOG_DIR:-/var/log/AxisLogNotifier}"

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
    echo "${LOG_DIR}/AxisLogNotifier_$(date +%Y-%m-%d).log"
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
    
    return 0
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
    
    # Initialiser le fichier de log
    if ! init_log_file "$log_file"; then
        log_file="/tmp/AxisLogNotifier_$(date +%Y-%m-%d).log"
        echo "Utilisation du fichier de fallback: $log_file"
        init_log_file "$log_file"
    fi
    
    # Écrire dans le log
    echo "$log_entry" >> "$log_file" 2>/dev/null || \
    echo "$log_entry" >> "/tmp/AxisLogNotifier_$(date +%Y-%m-%d).log"
}
