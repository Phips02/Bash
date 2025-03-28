#!/bin/bash

#A placer dans /usr/local/bin/ftp_video/ftp_monitor.sh

#Phips
# Version : 2024.12.26 21:00

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

# Gestion du signal d'arrêt
trap 'print_log "INFO" "monitor" "Arrêt du moniteur"; exit 0' SIGTERM SIGINT

# Boucle infinie avec pause de 15 secondes
while true; do
    # Exécuter le script principal
    print_log "INFO" "monitor" "Exécution du script principal"
    if ! /usr/local/bin/ftp_video/ftp_telegram.sh; then
        print_log "ERROR" "monitor" "Erreur lors de l'exécution du script principal"
    fi
    
    # Attendre 15 secondes
    sleep 15
done 