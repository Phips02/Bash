#!/bin/bash

#A placer dans /usr/local/bin/ftp_telegram.sh


#Phips
#Version : 2024.11.18 14:00


set -x

# Charger la configuration depuis le fichier
CONFIG_FILE="/etc/ftp_config.cfg"
source $CONFIG_FILE

# Définir les répertoires et fichiers
TEMP_DIR="/var/tmp/FTP_TEMP"
STATE_FILE="/var/tmp/FTP_FILES_SEEN.txt"

# Créer un répertoire temporaire pour stocker les fichiers téléchargés
mkdir -p $TEMP_DIR

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

  echo "Envoi du fichier $FILE_PATH à Telegram avec BOT_TOKEN=$BOT_TOKEN et CHAT_ID=$CHAT_ID..."

  # Envoi de la vidéo et capture de la réponse
  local RESPONSE=$(curl -s -w "%{http_code}" -X POST "https://api.telegram.org/bot$BOT_TOKEN/sendVideo" \
    -F chat_id="$CHAT_ID" \
    -F video="@$FILE_PATH" \
    -o /tmp/response_body.txt)

  # Extraction du code HTTP et du corps de la réponse
  local HTTP_CODE=$(tail -n 1 <<< "$RESPONSE")
  local RESPONSE_BODY=$(head -n -1 <<< "$RESPONSE")

  echo "Réponse HTTP : $HTTP_CODE"
  echo "Réponse de l'API Telegram :"
  cat /tmp/response_body.txt

  # Vérifier si la réponse est OK
  if [ "$HTTP_CODE" -eq 200 ] && echo "$RESPONSE_BODY" | grep -q '"ok":true'; then
    echo "Fichier $FILE_PATH envoyé avec succès à Telegram."
  else
    echo "Échec de l'envoi du fichier $FILE_PATH. Réponse : $RESPONSE_BODY"
    echo "Le fichier de réponse peut contenir des informations utiles :"
    cat /tmp/response_body.txt
  fi
}

# Récupérer la liste actuelle des fichiers dans le dossier FTP
echo "Téléchargement des fichiers depuis le serveur FTP..."
ftp -inv $FTP_HOST $FTP_PORT <<EOF | tee /tmp/ftp_debug.log
passive
user $FTP_USER $FTP_PASS
cd $FTP_DIR
lcd $TEMP_DIR
mget *.mkv
bye
EOF

# Vérifiez le contenu du répertoire temporaire
echo "Contenu du répertoire temporaire après téléchargement :"
ls -l $TEMP_DIR

# Créer le fichier d'état s'il n'existe pas
touch $STATE_FILE

# Envoyer les nouveaux fichiers .mkv à Telegram
ls -1 $TEMP_DIR/*.mkv | while read FILE; do
  # Vérifier si le fichier a déjà été envoyé
  if ! grep -Fxq "$(basename $FILE)" $STATE_FILE; then
    send_to_telegram "$FILE" "$TELEGRAM_CHAT_ID" "$TELEGRAM_BOT_TOKEN"
    # Ajouter le fichier au fichier d'état pour éviter les doublons
    echo "$(basename $FILE)" >> $STATE_FILE
  else
    echo "Fichier déjà envoyé : $(basename $FILE)"
  fi
done

# Nettoyer le répertoire temporaire
rm -rf $TEMP_DIR/*
