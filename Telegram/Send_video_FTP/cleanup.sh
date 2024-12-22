#!/bin/bash

#A placer dans /usr/local/bin/ftp_video/cleanup.sh

#Phips
#Version : 2024.12.22 20:10




# Charger la configuration
CONFIG_FILE="/etc/telegram/ftp_video/ftp_config.cfg"
source $CONFIG_FILE

# Charger le logger
source $LOGGER_PATH

# Fichiers et dossiers à nettoyer
STATE_FILE="/var/tmp/FTP_FILES_SEEN.txt"
TEMP_DIR="/var/tmp/FTP_TEMP"
LOG_DIR="/var/log/ftp_telegram"
MAX_LOG_DAYS=30  # Nombre de jours à conserver pour les logs

# Au début du script, après le chargement de la config
if [ ! -f "$LOGGER_PATH" ]; then
    echo "Logger non trouvé: $LOGGER_PATH"
    exit 1
fi

# Ajouter une fonction de vérification du logger
verify_logger() {
    if ! type log_info &>/dev/null || \
       ! type log_error &>/dev/null || \
       ! type log_critical &>/dev/null; then
        echo "Fonctions de logging non disponibles"
        exit 1
    fi
}

# Après le source du logger
verify_logger

# Fonction de nettoyage du fichier d'état
cleanup_state_file() {
    if [ -f "$STATE_FILE" ]; then
        log_info "cleanup" "Nettoyage du fichier d'état: $STATE_FILE"
        : > "$STATE_FILE"  # Vide le fichier tout en le préservant
    else
        log_warning "cleanup" "Fichier d'état non trouvé: $STATE_FILE"
        touch "$STATE_FILE"
    fi
}

# Fonction de nettoyage du dossier temporaire
cleanup_temp_dir() {
    if [ -d "$TEMP_DIR" ]; then
        log_info "cleanup" "Nettoyage du dossier temporaire: $TEMP_DIR"
        rm -rf "${TEMP_DIR:?}"/*
    else
        log_warning "cleanup" "Dossier temporaire non trouvé: $TEMP_DIR"
        mkdir -p "$TEMP_DIR"
    fi
}

# Fonction de gestion des logs
manage_logs() {
    if [ -d "$LOG_DIR" ]; then
        log_info "cleanup" "Gestion des fichiers de log dans: $LOG_DIR"
        
        # Compression des logs d'hier
        find "$LOG_DIR" -name "*.log" -type f -mtime 1 -exec gzip {} \;
        
        # Suppression des logs plus vieux que MAX_LOG_DAYS
        find "$LOG_DIR" -name "*.log.gz" -type f -mtime +$MAX_LOG_DAYS -delete
    else
        log_warning "cleanup" "Dossier de logs non trouvé: $LOG_DIR"
    fi
}

# Fonction de nettoyage des vidéos sur le FTP
cleanup_ftp_videos() {
    local temp_script="/tmp/ftp_cleanup.txt"
    local exit_code=0
    
    if [ ! -w "/tmp" ]; then
        log_critical "cleanup" "Impossible d'écrire dans /tmp"
        return 1
    fi

    log_info "cleanup" "Début du nettoyage FTP"

    # Vérification des paramètres FTP
    if [ -z "$FTP_HOST" ] || [ -z "$FTP_USER" ] || [ -z "$FTP_PASS" ] || [ -z "$FTP_DIR" ]; then
        log_error "cleanup" "Paramètres FTP manquants"
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

    # Exécution du script de nettoyage
    log_info "cleanup" "Suppression des fichiers sur le FTP"
    if ! lftp -f "$temp_script" 2> >(log_error "cleanup" "Erreur FTP: $(cat)"); then
        exit_code=$?
        log_error "cleanup" "Échec du nettoyage FTP (code: ${exit_code})"
    fi

    rm -f "$temp_script"
    return $exit_code
}

# Exécution des fonctions de nettoyage
log_info "cleanup" "Démarrage du processus de nettoyage"

cleanup_temp_dir
manage_logs
cleanup_ftp_videos
cleanup_state_file

log_info "cleanup" "Processus de nettoyage terminé"