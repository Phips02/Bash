#!/bin/bash

#A placer dans /usr/local/bin/ftp_video/ftp_monitor.sh

#Phips
#Version : 2024.03.24 09:35

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

# Boucle infinie avec pause de 15 secondes
while true; do
    # Exécuter le script principal
    print_log "info" "monitor" "Exécution du script principal"
    /usr/local/bin/ftp_video/ftp_telegram.sh
    
    # Attendre 15 secondes
    sleep 15
done 