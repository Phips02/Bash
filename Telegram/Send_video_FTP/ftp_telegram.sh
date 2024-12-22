#!/bin/bash

#A placer dans /usr/local/bin/ftp_video/ftp_telegram.sh

#Phips
#Version : 2024.12.22 13:41

set -x

# Charger la configuration depuis le fichier
CONFIG_FILE="/etc/telegram/ftp_video/ftp_config.cfg"
source $CONFIG_FILE

# Définir les répertoires et fichiers
TEMP_DIR="/var/tmp/FTP_TEMP"
STATE_FILE="/var/tmp/FTP_FILES_SEEN.txt"

# Ajouter une vérification du fichier de configuration
if [ ! -f "$CONFIG_FILE" ]; then
    echo "Erreur: Fichier de configuration non trouvé: $CONFIG_FILE"
    exit 1
fi

# Ajouter une gestion d'erreur pour le répertoire temporaire
if ! mkdir -p "$TEMP_DIR"; then
    echo "Erreur: Impossible de créer le répertoire temporaire: $TEMP_DIR"
    exit 1
fi

# Ajouter une vérification de l'existence des commandes requises
for cmd in lftp curl; do
    if ! command -v $cmd &> /dev/null; then
        echo "Erreur: $cmd n'est pas installé"
        exit 1
    fi
done

# Ajouter un nettoyage au début du script
trap 'rm -rf "$TEMP_DIR/*"' EXIT

# Fonction pour envoyer une vidéo à Telegram
send_to_telegram() {
    local FILE_PATH=$1
    local CHAT_ID=$2
    local BOT_TOKEN=$3

    if [ -z "$BOT_TOKEN" ];then
        echo "Erreur: BOT_TOKEN n'est pas défini."
        return 1
    fi

    if [ -z "$CHAT_ID" ];then
        echo "Erreur: CHAT_ID n'est pas défini."
        return 1
    fi

    echo "Envoi du fichier $FILE_PATH à Telegram..."

    # Envoi de la vidéo et capture de la réponse
    local RESPONSE=$(curl -s -w "%{http_code}" -X POST "https://api.telegram.org/bot$BOT_TOKEN/sendVideo" \
        -F chat_id="$CHAT_ID" \
        -F video="@$FILE_PATH" \
        -o /tmp/response_body.txt)

    local HTTP_CODE=$(tail -n 1 <<< "$RESPONSE")
    
    if [ "$HTTP_CODE" -eq 200 ]; then
        echo "Fichier $FILE_PATH envoyé avec succès à Telegram."
        return 0
    else
        echo "Échec de l'envoi du fichier $FILE_PATH."
        cat /tmp/response_body.txt
        return 1
    fi
}

# Récupérer les fichiers depuis le serveur FTP
echo "Téléchargement des fichiers depuis le serveur FTP..."
lftp -u $FTP_USER,$FTP_PASS $FTP_HOST:$FTP_PORT <<EOF || exit 1
set ssl:verify-certificate no
cd $FTP_DIR
lcd $TEMP_DIR
mget *.mkv
quit
EOF

# Vérifier le contenu du répertoire temporaire
echo "Contenu du répertoire temporaire après téléchargement :"
ls -l $TEMP_DIR

# Créer le fichier d'état s'il n'existe pas
touch $STATE_FILE

# Vérifier s'il y a des fichiers MKV
if ! ls $TEMP_DIR/*.mkv >/dev/null 2>&1; then
    echo "Aucun fichier MKV trouvé dans $TEMP_DIR"
    exit 0
fi

# Envoyer les nouveaux fichiers .mkv à Telegram
ls -1 $TEMP_DIR/*.mkv | while read FILE; do
    # Vérifier si le fichier a déjà été envoyé
    if ! grep -Fxq "$(basename $FILE)" $STATE_FILE; then
        if send_to_telegram "$FILE" "$TELEGRAM_CHAT_ID" "$TELEGRAM_BOT_TOKEN"; then
            # Ajouter le fichier au fichier d'état uniquement si l'envoi réussit
            echo "$(basename $FILE)" >> $STATE_FILE
        fi
    else
        echo "Fichier déjà envoyé : $(basename $FILE)"
    fi
done

# Nettoyer le répertoire temporaire
rm -rf $TEMP_DIR/*
