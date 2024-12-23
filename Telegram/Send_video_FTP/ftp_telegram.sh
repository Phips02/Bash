#!/bin/bash

#A placer dans /usr/local/bin/ftp_video/ftp_telegram.sh

#Phips
#Version : 2024.03.21 11:31

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
        echo "Erreur: $path_var n'est pas défini dans la configuration"
        exit 1
    fi
done

# Créer les répertoires nécessaires s'ils n'existent pas
for dir in "$LOG_DIR" "$TEMP_DIR" "$(dirname "$STATE_FILE")"; do
    if [ ! -d "$dir" ]; then
        mkdir -p "$dir" || {
            echo "Impossible de créer le répertoire: $dir"
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

# Fonction utilitaire pour combiner echo et log
print_log() {
    local level="$1"
    local component="$2"
    local message="$3"
    echo "$message"
    "log_${level}" "$component" "$message"
}

# Charger les fonctions Telegram
if [ ! -f "$TELEGRAM_FUNCTIONS" ]; then
    print_log "critical" "ftp_telegram" "Fonctions Telegram non trouvées: $TELEGRAM_FUNCTIONS"
    exit 1
fi
source "$TELEGRAM_FUNCTIONS"

# Vérifier si les fonctions de logging sont disponibles
if ! type log_info >/dev/null 2>&1; then
    print_log "error" "ftp_telegram" "Les fonctions de logging ne sont pas correctement chargées"
    exit 1
fi

# Log Démarrage du script
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
        
        if telegram_video_send "$FILE_PATH" "$CAPTION"; then
            print_log "debug" "ftp_telegram" "Envoi Telegram réussi pour: ${FILE_NAME}"
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

# Fonction process_ftp
process_ftp() {
    print_log "info" "ftp_telegram" "Démarrage du traitement FTP"
    local dirs_file=$(mktemp)
    local error_file=$(mktemp)
    local error_count=0
    
    # Nettoyer le dossier temporaire avant de commencer
    rm -rf "${TEMP_DIR:?}"/*
    
    # Récupération de la liste des dossiers avec capture détaillée des erreurs
    if ! lftp -u "$FTP_USER,$FTP_PASS" "$FTP_HOST:$FTP_PORT" \
        -e "set ssl:verify-certificate no; cd \"$FTP_DIR\"; ls -R; quit" \
        > "$dirs_file" 2>"$error_file"; then
        
        local error_msg=$(cat "$error_file")
        if [ -n "$error_msg" ]; then
            print_log "error" "ftp_telegram" "Erreur FTP: $error_msg"
        else
            print_log "error" "ftp_telegram" "Erreur FTP inconnue lors de la connexion"
        fi
        
        rm -f "$dirs_file" "$error_file"
        return 1
    fi

    # Vérifier si le fichier de sortie est vide
    if [ ! -s "$dirs_file" ]; then
        print_log "error" "ftp_telegram" "Aucune donnée reçue du serveur FTP"
        rm -f "$dirs_file" "$error_file"
        return 1
    fi

    # Traiter chaque dossier séparément
    grep "^./.*:$" "$dirs_file" | sed 's/:$//' | while read dir; do
        print_log "info" "ftp_telegram" "Analyse du dossier: $dir"
        
        # Ignorer les dossiers système
        skip=0
        for ignore in "${IGNORE_DIRS[@]}"; do
            if [[ "$dir" == *"$ignore"* ]]; then
                print_log "debug" "ftp_telegram" "Dossier ignoré: $dir"
                skip=1
                break
            fi
        done
        
        if [ "$skip" -eq 1 ]; then
            continue
        fi

        if [ "$dir" != "." ]; then
            print_log "info" "ftp_telegram" "Traitement du dossier: $dir"
            mkdir -p "$TEMP_DIR/$dir" || {
                print_log "error" "ftp_telegram" "Impossible de créer le dossier $TEMP_DIR/$dir"
                continue
            }
            
            # Télécharger les fichiers du dossier avec l'option set xfer:clobber
            lftp -u $FTP_USER,$FTP_PASS $FTP_HOST:$FTP_PORT <<EOF
            set ssl:verify-certificate no
            set xfer:clobber yes
            cd "$FTP_DIR/$dir"
            lcd "$TEMP_DIR/$dir"
            mget *.mkv
            quit
EOF
        fi
    done

    rm -f "$dirs_file" "$error_file"
    print_log "info" "ftp_telegram" "Fin du traitement FTP"

    # Traiter les fichiers téléchargés
    find "$TEMP_DIR" -type f -name "*.mkv" | while read FILE; do
        # Extraire le nom du client depuis le chemin relatif
        relative_path=${FILE#$TEMP_DIR/}
        client_name=$(dirname "$relative_path")
        
        # Vérifier si le fichier a déjà été envoyé
        if ! grep -Fxq "$relative_path" $STATE_FILE; then
            if send_to_telegram "$FILE" "$TELEGRAM_CHAT_ID" "$TELEGRAM_BOT_TOKEN" "$client_name"; then
                echo "$relative_path" >> $STATE_FILE
                print_log "info" "ftp_telegram" "Fichier envoyé avec succès: $relative_path"
            fi
        else
            print_log "info" "ftp_telegram" "Fichier déjà envoyé: $relative_path"
        fi
    done
}

# Utiliser la nouvelle fonction
process_ftp

# Nettoyer le répertoire temporaire
rm -rf $TEMP_DIR/*
