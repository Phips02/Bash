#!/bin/bash

#A placer dans /usr/local/bin/ftp_video/test_ftp.sh

#Phips
#Version : 2024.12.22 13:41

# Charger la configuration depuis le fichier
source /etc/telegram/ftp_video/ftp_config.cfg

# Fonction pour lister le contenu du FTP
function list_ftp_content() {
    local temp_file="/tmp/ftp_listing.txt"
    local timeout=30
    
    # Vérifier les paramètres FTP
    if [ -z "$FTP_HOST" ] || [ -z "$FTP_USER" ] || [ -z "$FTP_PASS" ] || [ -z "$FTP_DIR" ]; then
        echo "Erreur: Paramètres FTP manquants dans la configuration"
        return 1
    fi

    echo "Connexion au serveur FTP ${FTP_HOST}:${FTP_PORT}"
    echo "Listage du répertoire: ${FTP_DIR}"
    
    # Exécuter la commande LFTP et sauvegarder la sortie
    timeout $timeout lftp -u $FTP_USER,$FTP_PASS $FTP_HOST:$FTP_PORT <<EOF > "$temp_file" 2>&1
set ssl:verify-certificate no
cd $FTP_DIR
ls
quit
EOF

    # Vérifier si la connexion a réussi
    if grep -q "Access failed" "$temp_file"; then
        echo "Erreur de connexion au serveur FTP"
        cat "$temp_file"
        rm "$temp_file"
        return 1
    else
        echo "Connexion réussie!"
        echo "Contenu du répertoire ${FTP_DIR}:"
        echo "--------------------------------"
        cat "$temp_file"
    fi

    # Nettoyer le fichier temporaire
    rm "$temp_file"
}

# Exécuter la fonction
list_ftp_content

