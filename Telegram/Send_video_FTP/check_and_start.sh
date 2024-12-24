#!/bin/bash

# A placer dans /usr/local/bin/ftp_video/check_and_start.sh

# Phips
# Version : 2024.03.24 16:00

# Charger la configuration
CONFIG_FILE="/etc/telegram/ftp_video/ftp_config.cfg"

# Vérifier si le fichier de configuration existe
if [ ! -f "$CONFIG_FILE" ]; then
    echo "Fichier de configuration non trouvé: $CONFIG_FILE"
    exit 1
fi

# Charger la configuration
source "$CONFIG_FILE"

# Charger le logger
source "$LOGGER_PATH"

# Vérification immédiate du logger
if ! declare -f print_log >/dev/null; then
    echo "ERREUR: Logger non chargé correctement"
    exit 1
fi

# Vérifier si le script est en cours d'exécution
if ! /usr/bin/pgrep -f "ftp_monitor.sh" > /dev/null; then
    print_log "info" "check_and_start" "ftp_monitor.sh n'est pas en cours d'exécution, démarrage..."
    /usr/local/bin/ftp_video/ftp_monitor.sh > /dev/null 2>&1 &
else
    print_log "info" "check_and_start" "ftp_monitor.sh est déjà en cours d'exécution"
fi 