#!/bin/bash

#A placer dans /usr/local/bin/ftp_video/cleanup.sh

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
for path_var in "BASE_DIR" "CONFIG_BASE_DIR" "LOG_DIR" "TEMP_DIR" "LOGGER_PATH" "STATE_FILE"; do
    if [ -z "${!path_var}" ]; then
        echo "Erreur: $path_var n'est pas défini dans la configuration"
        exit 1
    fi
done

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

# Configuration de la rétention des logs
MAX_LOG_DAYS=30  # Nombre de jours à conserver pour les logs

# Ajouter une fonction de vérification du logger
verify_logger() {
    if ! type log_info &>/dev/null || \
       ! type log_error &>/dev/null || \
       ! type log_critical &>/dev/null; then
        print_log "critical" "cleanup" "Fonctions de logging non disponibles"
        exit 1
    fi
}

# Après le source du logger
verify_logger

print_log "info" "cleanup" "Démarrage du script de nettoyage"

# Fonction de nettoyage du fichier d'état
cleanup_state_file() {
    if [ -f "$STATE_FILE" ]; then
        print_log "info" "cleanup" "Nettoyage du fichier d'état: $STATE_FILE"
        : > "$STATE_FILE"  # Vide le fichier tout en le préservant
    else
        print_log "warning" "cleanup" "Fichier d'état non trouvé: $STATE_FILE"
        touch "$STATE_FILE"
    fi
}

# Fonction de nettoyage du dossier temporaire
cleanup_temp_dir() {
    if [ -d "$TEMP_DIR" ]; then
        print_log "info" "cleanup" "Nettoyage du dossier temporaire: $TEMP_DIR"
        rm -rf "${TEMP_DIR:?}"/*
    else
        print_log "warning" "cleanup" "Dossier temporaire non trouvé: $TEMP_DIR"
        mkdir -p "$TEMP_DIR"
    fi
}

# Fonction de gestion des logs
manage_logs() {
    if [ -d "$LOG_DIR" ]; then
        print_log "info" "cleanup" "Gestion des fichiers de log dans: $LOG_DIR"
        
        # Compression des logs d'hier
        find "$LOG_DIR" -name "ftp_telegram_*.log" -type f -dayold 1 | while read logfile; do
            if [ -f "$logfile" ]; then
                print_log "info" "cleanup" "Compression du fichier: $logfile"
                gzip -f "$logfile"
            fi
        done
        
        # Suppression des vieux logs
        local deleted_count=0
        while read -r old_log; do
            if rm "$old_log"; then
                ((deleted_count++))
            fi
        done < <(find "$LOG_DIR" -name "ftp_telegram_*.log.gz" -type f -mtime +$MAX_LOG_DAYS)
        
        if [ $deleted_count -gt 0 ]; then
            print_log "info" "cleanup" "$deleted_count fichiers de log anciens supprimés"
        fi
    else
        print_log "warning" "cleanup" "Dossier de logs non trouvé: $LOG_DIR"
        mkdir -p "$LOG_DIR"
    fi
}

# Fonction de nettoyage des vidéos sur le FTP
cleanup_ftp_videos() {
    local temp_script="/tmp/ftp_cleanup.txt"
    local error_file="/tmp/ftp_error.txt"
    local exit_code=0
    
    if [ ! -w "/tmp" ]; then
        print_log "critical" "cleanup" "Impossible d'écrire dans /tmp"
        return 1
    fi

    print_log "info" "cleanup" "Début du nettoyage FTP"

    # Vérification des paramètres FTP
    if [ -z "$FTP_HOST" ] || [ -z "$FTP_USER" ] || [ -z "$FTP_PASS" ] || [ -z "$FTP_DIR" ]; then
        print_log "error" "cleanup" "Paramètres FTP manquants"
        return 1
    fi

    cat > "$temp_script" << EOF
set ssl:verify-certificate no
open -u ${FTP_USER},${FTP_PASS} ${FTP_HOST}:${FTP_PORT}
cd ${FTP_DIR}
# Supprimer tous les fichiers .mkv récursivement
mrm -r */*.mkv
# Supprimer les dossiers vides
glob -a rm *
quit
EOF

    # Exécution du script de nettoyage avec capture des erreurs
    print_log "info" "cleanup" "Suppression des fichiers sur le FTP"
    if ! lftp -f "$temp_script" 2>"$error_file"; then
        exit_code=$?
        if [ -s "$error_file" ]; then
            local error_msg=$(cat "$error_file")
            print_log "error" "cleanup" "Erreur FTP: ${error_msg}"
        else
            print_log "error" "cleanup" "Erreur FTP inconnue (code: ${exit_code})"
        fi
    else
        print_log "info" "cleanup" "Nettoyage FTP terminé avec succès"
    fi

    # Nettoyage des fichiers temporaires
    rm -f "$temp_script" "$error_file"
    return $exit_code
}

# Exécution des fonctions de nettoyage
cleanup_temp_dir
manage_logs
cleanup_ftp_videos
cleanup_state_file

print_log "info" "cleanup" "Processus de nettoyage terminé"