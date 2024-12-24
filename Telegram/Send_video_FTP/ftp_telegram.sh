#!/bin/bash

#A placer dans /usr/local/bin/ftp_video/ftp_telegram.sh

#Phips
#Version : 2024.12.24 10:05

# Charger la configuration
CONFIG_FILE="/etc/telegram/ftp_video/ftp_config.cfg"

# Vérifier si le fichier de configuration existe
if [ ! -f "$CONFIG_FILE" ]; then
    echo "Fichier de configuration non trouvé: $CONFIG_FILE"
    exit 1
fi

# Charger la configuration
source "$CONFIG_FILE"

# Vérifier les chemins essentiels
for path_var in "BASE_DIR" "CONFIG_BASE_DIR" "LOG_DIR" "TEMP_DIR" "LOGGER_PATH" "TELEGRAM_FUNCTIONS" "STATE_FILE"; do
    if [ -z "${!path_var}" ]; then
        print_log "critical" "ftp_telegram" "$path_var n'est pas défini dans la configuration"
        exit 1
    fi
done

# Créer les répertoires nécessaires s'ils n'existent pas
for dir in "$LOG_DIR" "$TEMP_DIR" "$(dirname "$STATE_FILE")"; do
    if [ ! -d "$dir" ]; then
        mkdir -p "$dir" || {
            print_log "critical" "ftp_telegram" "Impossible de créer le répertoire: $dir"
            exit 1
        }
    fi
done

# Créer le fichier d'état s'il n'existe pas
if [ ! -f "$STATE_FILE" ]; then
    touch "$STATE_FILE" || {
        echo "Impossible de créer le fichier d'état: $STATE_FILE"
        exit 1
    }
fi

# Vérifier si le fichier logger existe
if [ ! -f "$LOGGER_PATH" ]; then
    echo "Logger non trouvé: $LOGGER_PATH"
    exit 1
fi

# Charger le logger
source "$LOGGER_PATH"
# Vérification immédiate du logger
if ! declare -f log_info >/dev/null; then
    echo "ERREUR: Logger non chargé correctement"
    exit 1
fi

source "$TELEGRAM_FUNCTIONS"
# Vérification immédiate des fonctions Telegram
if ! declare -f telegram_video_send >/dev/null; then
    print_log "critical" "ftp_telegram" "Fonctions Telegram non chargées"
    exit 1
fi

# Test immédiat du logger
print_log "info" "ftp_telegram" "Démarrage du script"

# Vérification et création des dossiers nécessaires
if [ ! -d "$TEMP_DIR" ]; then
    print_log "info" "ftp_telegram" "Création du répertoire temporaire: $TEMP_DIR"
    mkdir -p "$TEMP_DIR" || {
        print_log "critical" "ftp_telegram" "Impossible de créer $TEMP_DIR"
        exit 1
    }
fi

# Ignorer les dossiers système
IGNORE_DIRS=("@eaDir" "@tmp")

# Vérifier l'existence des commandes requises
for cmd in lftp curl; do
    if ! command -v $cmd &> /dev/null; then
        print_log "critical" "ftp_telegram" "$cmd n'est pas installé"
        exit 1
    fi
done

# Ajouter un nettoyage au début du script
trap 'rm -rf "$TEMP_DIR/*"' EXIT

# Fonction pour envoyer une vidéo à Telegram
send_to_telegram() {
    local FILE_PATH="$1"
    local CHAT_ID="$2"
    local BOT_TOKEN="$3"
    local SOURCE_DIR="$4"
    local max_retries=3
    local retry_count=0
    
    # Obtenir le nom du fichier
    local FILE_NAME=$(basename "$FILE_PATH")
    # Préparer la description avec le dossier source et le nom du fichier
    local CAPTION="$SOURCE_DIR
$FILE_NAME"

    while [ $retry_count -lt $max_retries ]; do
        print_log "info" "ftp_telegram" "Tentative d'envoi ($((retry_count+1))/$max_retries): ${FILE_NAME}"
        
        if telegram_video_send "$FILE_PATH" "$CAPTION" "$CHAT_ID"; then
            print_log "info" "ftp_telegram" "Fichier envoyé avec succès: ${FILE_NAME}"
            return 0
        fi
        
        ((retry_count++))
        if [ $retry_count -lt $max_retries ]; then
            print_log "info" "ftp_telegram" "Nouvelle tentative dans 5 secondes"
            sleep 5
        fi
    done
    
    print_log "error" "ftp_telegram" "Échec de l'envoi après $max_retries tentatives: ${FILE_NAME}"
    return 1
}

# Fonction pour créer le dossier local correspondant
create_local_dir() {
    local remote_dir=$1
    local local_base_dir="$TEMP_DIR"
    local local_dir="${local_base_dir}${remote_dir}"
    
    mkdir -p "$local_dir"
    echo "$local_dir"
}

# Fonction pour obtenir le chat ID spécifique au client
get_client_chat_id() {
    local client_name="$1"
    local var_name="CLIENT_CHAT_IDS_${client_name}"
    local chat_id="${!var_name}"
    
    if [ -n "$chat_id" ]; then
        echo "$chat_id"
    else
        echo "$DEFAULT_TELEGRAM_CHAT_ID"
    fi
}

# Fonction process_ftp
process_ftp() {
    print_log "info" "ftp_telegram" "Démarrage du traitement FTP"
    local error_file=$(mktemp)
    
    # Vérifier et créer le TEMP_DIR avec les bonnes permissions
    if [ ! -d "$TEMP_DIR" ]; then
        print_log "info" "ftp_telegram" "Création du répertoire temporaire: $TEMP_DIR"
        mkdir -p "$TEMP_DIR" || {
            print_log "critical" "ftp_telegram" "Impossible de créer $TEMP_DIR"
            return 1
        }
        # Ajouter les bonnes permissions
        chmod 755 "$TEMP_DIR"
    fi
    
    # Nettoyer le dossier temporaire avant de commencer
    rm -rf "${TEMP_DIR:?}"/*
    
    # Créer le script FTP avec des options supplémentaires
    local ftp_script=$(mktemp)
    cat > "$ftp_script" <<EOF
open -u "$FTP_USER","$FTP_PASS" "$FTP_HOST:$FTP_PORT"
set ssl:verify-certificate no
set xfer:clobber yes
set net:max-retries 3
set net:timeout 10
set net:reconnect-interval-base 5
cd "$FTP_DIR"

# Obtenir la liste des dossiers et les traiter
mirror --only-newer -i "\.mkv$" --exclude "@eaDir/" --exclude "@tmp/" --parallel=1 --use-cache . "$TEMP_DIR"

quit
EOF

    # Exécuter le script FTP avec vérification du statut
    print_log "info" "ftp_telegram" "Démarrage du téléchargement des fichiers"
    if ! lftp -f "$ftp_script" 2>"$error_file"; then
        if grep -q "No such file or directory" "$error_file"; then
            print_log "warning" "ftp_telegram" "Aucun nouveau fichier à télécharger"
        else
            print_log "error" "ftp_telegram" "Erreur lors du téléchargement des fichiers"
            cat "$error_file" | while read line; do
                print_log "error" "ftp_telegram" "$line"
            done
        fi
    fi

    # Nettoyage des fichiers temporaires
    rm -f "$error_file" "$ftp_script"
    print_log "info" "ftp_telegram" "Fin du traitement FTP"

    # Traitement des fichiers téléchargés
    find "$TEMP_DIR" -type f -name "*.mkv" | while read FILE; do
        relative_path=${FILE#$TEMP_DIR/}
        client_name=$(dirname "$relative_path")
        client_chat_id=$(get_client_chat_id "$client_name")
        
        if ! grep -Fxq "$relative_path" $STATE_FILE; then
            if send_to_telegram "$FILE" "$client_chat_id" "$TELEGRAM_BOT_TOKEN" "$client_name"; then
                echo "$relative_path" >> $STATE_FILE
                print_log "info" "ftp_telegram" "Fichier envoyé avec succès à $client_name (Chat ID: $client_chat_id): $relative_path"
            fi
        else
            print_log "info" "ftp_telegram" "Fichier déjà envoyé : $relative_path"
        fi
    done
}

# Utiliser la nouvelle fonction
process_ftp

# Nettoyer le répertoire temporaire
rm -rf $TEMP_DIR/*