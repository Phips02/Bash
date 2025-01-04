#!/bin/bash

###############################################################################
# Script de mise à jour des notifications Telegram
# Version 3.4
###############################################################################

# Définition des chemins
BASE_DIR="/usr/local/bin/telegram/notif_connexion"
CONFIG_DIR="/etc/telegram/notif_connexion"
BACKUP_DIR="$CONFIG_DIR/backup"
SCRIPT_PATH="$BASE_DIR/telegram.sh"
CONFIG_PATH="$CONFIG_DIR/telegram.config"

# Fonction pour le logging avec horodatage et niveau
function log_message() {
    local level="$1"
    local message="$2"
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] [$level] $message"
}

# Fonction pour tracer les erreurs des commandes
function execute_command() {
    local cmd="$1"
    local description="$2"
    
    if ! eval "$cmd" 2>/tmp/cmd_error.log; then
        local error=$(cat /tmp/cmd_error.log)
        log_message "ERROR" "Échec de $description: $error"
        rm -f /tmp/cmd_error.log
        return 1
    fi
    rm -f /tmp/cmd_error.log
    return 0
}

# Fonction pour la configuration PAM
function configure_pam() {
    if ! grep -q "session.*telegram.sh" /etc/pam.d/su; then
        log_message "INFO" "Configuration PAM manquante, installation..."
        if ! execute_command "echo 'session optional pam_exec.so seteuid /bin/bash -c \"source $CONFIG_DIR/telegram.config 2>/dev/null && \$SCRIPT_PATH\"' >> /etc/pam.d/su" "configuration de PAM"; then
            log_message "ERROR" "Échec de la configuration PAM"
            return 1
        fi
        log_message "SUCCESS" "Configuration PAM installée"
    else
        log_message "INFO" "Configuration PAM déjà présente"
    fi
    return 0
}

# Vérification des droits root
if [[ $EUID -ne 0 ]]; then
    log_message "ERROR" "Ce script doit être exécuté en tant que root"
    exit 1
fi

# Création des répertoires nécessaires
mkdir -p "$BASE_DIR" "$CONFIG_DIR" "$BACKUP_DIR"

# Sauvegarde de la configuration existante
if [ -f "$CONFIG_PATH" ]; then
    BACKUP_DATE=$(date +%Y%m%d_%H%M%S)
    cp "$CONFIG_PATH" "$BACKUP_DIR/telegram.config.$BACKUP_DATE"
    cp "$SCRIPT_PATH" "$BACKUP_DIR/telegram.sh.$BACKUP_DATE"
    log_message "INFO" "Sauvegarde créée: $BACKUP_DATE"
fi

# Mise à jour des fichiers
log_message "INFO" "Téléchargement des nouveaux fichiers..."
REPO_URL="https://raw.githubusercontent.com/Phips02/Bash/main/Telegram/Telegram%20-%20telegram_notif_v2"

# Téléchargement et installation du script principal
if ! execute_command "wget -q '$REPO_URL/telegram.sh' -O '$SCRIPT_PATH'" "téléchargement du script"; then
    exit 1
fi

if ! execute_command "chmod 750 '$SCRIPT_PATH'" "configuration des permissions du script"; then
    exit 1
fi

# Configuration PAM
if ! configure_pam; then
    log_message "ERROR" "Échec de la configuration PAM"
    exit 1
fi

# Nettoyage
log_message "INFO" "Nettoyage des anciennes sauvegardes..."
cd "$BACKUP_DIR" && ls -t telegram.* | tail -n +11 | xargs -r rm

# Message final
log_message "SUCCESS" "Mise à jour terminée avec succès!"
log_message "INFO" "Redémarrez votre session pour activer les changements"

exit 0