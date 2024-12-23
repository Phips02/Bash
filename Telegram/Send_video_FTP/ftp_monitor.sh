#!/bin/bash

#A placer dans /usr/local/bin/ftp_video/ftp_monitor.sh

#Phips
#Version : 2024.03.23 15:26

# Charger la configuration
CONFIG_FILE="/etc/telegram/ftp_video/ftp_config.cfg"

# Vérifier si le fichier de configuration existe
if [ ! -f "$CONFIG_FILE" ]; then
    echo "Fichier de configuration non trouvé: $CONFIG_FILE"
    exit 1
fi

# Charger la configuration
source "$CONFIG_FILE"

# Boucle infinie avec pause de 15 secondes
while true; do
    # Exécuter le script principal
    /usr/local/bin/ftp_video/ftp_telegram.sh
    
    # Attendre 15 secondes
    sleep 15
done 