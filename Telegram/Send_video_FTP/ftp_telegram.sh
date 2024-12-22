#!/bin/bash

#A placer dans /usr/local/bin/ftp_video/ftp_telegram.sh

#Phips
#Version : 2024.12.22 20:10



# Charger la configuration depuis le fichier
CONFIG_FILE="/etc/telegram/ftp_video/ftp_config.cfg"

# Vérifier si le fichier de configuration existe
if [ ! -f "$CONFIG_FILE" ]; then
    echo "Erreur: Fichier de configuration non trouvé: $CONFIG_FILE"
    exit 1
fi

# Charger la configuration
source "$CONFIG_FILE"

# Vérifier si LOGGER_PATH est défini
if [ -z "$LOGGER_PATH" ]; then
    echo "Erreur: LOGGER_PATH n'est pas défini dans la configuration"
    exit 1
fi

# Vérifier si le fichier logger existe
if [ ! -f "$LOGGER_PATH" ]; then
    echo "Erreur: Logger non trouvé: $LOGGER_PATH"
    exit 1
fi

# Charger le logger
source "$LOGGER_PATH"

# Vérifier si les fonctions de logging sont disponibles
if ! type log_info >/dev/null 2>&1; then
    echo "Erreur: Les fonctions de logging ne sont pas correctement chargées"
    exit 1
fi

# Test immédiat du logger
log_info "ftp_telegram" "Démarrage du script"

# Définir les répertoires et fichiers
TEMP_DIR="/var/tmp/FTP_TEMP"
STATE_FILE="/var/tmp/FTP_FILES_SEEN.txt"

# Ajouter une vérification du fichier de configuration
if [ ! -f "$CONFIG_FILE" ]; then
    log_critical "ftp_telegram" "Fichier de configuration non trouvé: $CONFIG_FILE"
    exit 1
fi

# Au début du script, après le chargement de la configuration
# Vérification et création des dossiers nécessaires
if [ ! -d "$TEMP_DIR" ]; then
    log_info "ftp_telegram" "Création du répertoire temporaire: $TEMP_DIR"
    mkdir -p "$TEMP_DIR" || {
        log_critical "ftp_telegram" "Impossible de créer $TEMP_DIR"
        exit 1
    }
fi

# Ignorer les dossiers système
IGNORE_DIRS=("@eaDir" "@tmp")

# Ajouter une gestion d'erreur pour le répertoire temporaire
if ! mkdir -p "$TEMP_DIR"; then
    log_critical "ftp_telegram" "Impossible de créer le répertoire temporaire: $TEMP_DIR"
    exit 1
fi

# Ajouter une vérification de l'existence des commandes requises
for cmd in lftp curl; do
    if ! command -v $cmd &> /dev/null; then
        log_critical "ftp_telegram" "$cmd n'est pas installé"
        exit 1
    fi
done

# Ajouter un nettoyage au début du script
trap 'rm -rf "$TEMP_DIR/*"' EXIT

# Au début du script
if [ ! -f "$LOGGER_PATH" ]; then
    echo "Logger non trouvé: $LOGGER_PATH"
    exit 1
fi

# Fonction pour envoyer une vidéo à Telegram
send_to_telegram() {
    local FILE_PATH="$1"
    local CHAT_ID="$2"
    local BOT_TOKEN="$3"
    local SOURCE_DIR="$4"
    local max_retries=3
    local retry_count=0
    local curl_output
    local http_code
    
    # Obtenir le nom du fichier
    local FILE_NAME=$(basename "$FILE_PATH")
    # Préparer la description avec le dossier source et le nom du fichier
    local CAPTION="$SOURCE_DIR
$FILE_NAME"

    while [ $retry_count -lt $max_retries ]; do
        curl_output=$(mktemp)
        
        http_code=$(curl -s -w "%{http_code}" -X POST \
            "https://api.telegram.org/bot${BOT_TOKEN}/sendVideo" \
            -F "chat_id=${CHAT_ID}" \
            -F "video=@${FILE_PATH}" \
            -F "caption=${CAPTION}" \
            -F "parse_mode=HTML" \
            -o "$curl_output")

        if [ "$http_code" = "200" ]; then
            log_info "ftp_telegram" "Fichier envoyé avec succès: ${CAPTION}"
            rm -f "$curl_output"
            return 0
        fi

        log_warning "ftp_telegram" "Tentative $((retry_count+1))/$max_retries échouée (HTTP $http_code)"
        log_debug "ftp_telegram" "Réponse Telegram: $(cat "$curl_output")"
        
        rm -f "$curl_output"
        ((retry_count++))
        sleep 5
    done
    
    log_error "ftp_telegram" "Échec de l'envoi après $max_retries tentatives"
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

# Remplacer la fonction process_ftp par :
process_ftp() {
    log_info "ftp_telegram" "Démarrage du traitement FTP"
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
            log_error "ftp_telegram" "Erreur FTP: $error_msg"
        else
            log_error "ftp_telegram" "Erreur FTP inconnue lors de la connexion"
        fi
        
        rm -f "$dirs_file" "$error_file"
        return 1
    fi

    # Vérifier si le fichier de sortie est vide
    if [ ! -s "$dirs_file" ]; then
        log_error "ftp_telegram" "Aucune donnée reçue du serveur FTP"
        rm -f "$dirs_file" "$error_file"
        return 1
    fi

    # Ensuite, traiter chaque dossier séparément
    grep "^./.*:$" "$dirs_file" | sed 's/:$//' | while read dir; do
        log_info "ftp_telegram" "Analyse du dossier: $dir"
        
        # Ignorer les dossiers système
        skip=0
        for ignore in "${IGNORE_DIRS[@]}"; do
            if [[ "$dir" == *"$ignore"* ]]; then
                log_debug "ftp_telegram" "Dossier ignoré: $dir"
                skip=1
                break
            fi
        done
        
        if [ "$skip" -eq 1 ]; then
            continue
        fi

        if [ "$dir" != "." ]; then
            log_info "ftp_telegram" "Traitement du dossier: $dir"
            mkdir -p "$TEMP_DIR/$dir" || {
                log_error "ftp_telegram" "Impossible de créer le dossier $TEMP_DIR/$dir"
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
    log_info "ftp_telegram" "Fin du traitement FTP"

    # Traiter les fichiers téléchargés
    find "$TEMP_DIR" -type f -name "*.mkv" | while read FILE; do
        # Extraire le nom du client depuis le chemin relatif
        relative_path=${FILE#$TEMP_DIR/}
        client_name=$(dirname "$relative_path")
        
        # Vérifier si le fichier a déjà été envoyé
        if ! grep -Fxq "$relative_path" $STATE_FILE; then
            if send_to_telegram "$FILE" "$TELEGRAM_CHAT_ID" "$TELEGRAM_BOT_TOKEN" "$client_name"; then
                echo "$relative_path" >> $STATE_FILE
            fi
        else
            log_info "ftp_telegram" "Fichier déjà envoyé : $relative_path"
        fi
    done
}

# Utiliser la nouvelle fonction
process_ftp

# Nettoyer le répertoire temporaire
rm -rf $TEMP_DIR/*
