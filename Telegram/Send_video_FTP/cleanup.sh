#!/bin/bash

#A placer dans /usr/local/bin/ftp_video/cleanup.sh

#Phips
# Version : 2024.12.26 21:00


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

# Charger le logger
source "$LOGGER_PATH"

# Vérification immédiate du logger
if ! declare -f print_log >/dev/null; then
    echo "ERREUR: Logger non chargé correctement"
    exit 1
fi

print_log "INFO" "cleanup" "Démarrage du script de nettoyage"

# Fonction de nettoyage du dossier temporaire
cleanup_temp_dir() {
    if [ -d "$TEMP_DIR" ]; then
        print_log "INFO" "cleanup" "Nettoyage du dossier temporaire: $TEMP_DIR"
        rm -rf "${TEMP_DIR:?}"/*
    else
        print_log "WARNING" "cleanup" "Dossier temporaire non trouvé: $TEMP_DIR"
        mkdir -p "$TEMP_DIR"
    fi
}

# Fonction de gestion des logs
manage_logs() {
    if [ -d "$LOG_DIR" ]; then
        print_log "INFO" "cleanup" "Gestion des fichiers de log dans: $LOG_DIR"
        find "$LOG_DIR" -name "ftp_telegram_*.log" -type f -mtime 1 -exec gzip {} \;
    else
        print_log "WARNING" "cleanup" "Dossier de logs non trouvé: $LOG_DIR"
        mkdir -p "$LOG_DIR"
    fi
}

# Fonction de nettoyage du fichier d'état
cleanup_state_file() {
    if [ -f "$STATE_FILE" ]; then
        print_log "INFO" "cleanup" "Nettoyage du fichier d'état: $STATE_FILE"
        : > "$STATE_FILE"  # Vide le fichier tout en le préservant
    else
        print_log "WARNING" "cleanup" "Fichier d'état non trouvé: $STATE_FILE"
        touch "$STATE_FILE"
    fi
}

# Fonction unique de nettoyage FTP
cleanup_ftp() {
    local check_script="/tmp/ftp_check.txt"
    local temp_script="/tmp/ftp_cleanup.txt"
    local error_file="/tmp/ftp_error.txt"
    
    print_log "INFO" "cleanup" "Début du nettoyage FTP"

    # Vérification des paramètres FTP
    if [ -z "$FTP_HOST" ] || [ -z "$FTP_USER" ] || [ -z "$FTP_PASS" ] || [ -z "$FTP_DIR" ]; then
        print_log "ERROR" "cleanup" "Paramètres FTP manquants"
        return 1
    fi

    # Vérifier si le dossier est vide
    cat > "$check_script" << EOF
set ssl:verify-certificate no
open -u ${FTP_USER},${FTP_PASS} ${FTP_HOST}:${FTP_PORT}
cd ${FTP_DIR}
cls -1
quit
EOF

    if ! lftp -f "$check_script" | grep -q .; then
        print_log "INFO" "cleanup" "Le dossier FTP est déjà vide"
        rm -f "$check_script"
        return 0
    fi

    # Si non vide, procéder au nettoyage
    cat > "$temp_script" << EOF
set ssl:verify-certificate no
open -u ${FTP_USER},${FTP_PASS} ${FTP_HOST}:${FTP_PORT}
cd ${FTP_DIR}
glob -a rm -rf *
rm -rf */
quit
EOF

    if lftp -f "$temp_script" 2>"$error_file"; then
        print_log "INFO" "cleanup" "Nettoyage FTP terminé avec succès"
    else
        if [ -s "$error_file" ]; then
            print_log "ERROR" "cleanup" "Erreur FTP: $(cat "$error_file")"
        else
            print_log "ERROR" "cleanup" "Erreur FTP inconnue"
        fi
    fi

    # Nettoyage des fichiers temporaires
    rm -f "$temp_script" "$error_file" "$check_script"
}

# Exécution des fonctions de nettoyage

cleanup_ftp
cleanup_temp_dir
manage_logs
cleanup_state_file

print_log "INFO" "cleanup" "Processus de nettoyage terminé"