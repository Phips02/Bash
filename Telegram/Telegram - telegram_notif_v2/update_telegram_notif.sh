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
wget -q "$REPO_URL/telegram.sh" -O "$SCRIPT_PATH"
if [ $? -ne 0 ]; then
    log_message "ERROR" "Échec du téléchargement du script"
    exit 1
fi

chmod 750 "$SCRIPT_PATH"
if [ $? -ne 0 ]; then
    log_message "ERROR" "Échec de la configuration des permissions"
    exit 1
fi

# Configuration PAM
PAM_LINE="session optional pam_exec.so seteuid /bin/bash -c \"source $CONFIG_DIR/telegram.config 2>/dev/null && \$SCRIPT_PATH\""
PAM_FILE="/etc/pam.d/su"

log_message "INFO" "Vérification de la configuration PAM..."

# Nettoyer complètement toutes les configurations Telegram
if grep -q "telegram" "$PAM_FILE"; then
    log_message "INFO" "Nettoyage des anciennes configurations PAM..."
    # Créer un fichier temporaire sans les lignes Telegram
    grep -v "telegram" "$PAM_FILE" > "$PAM_FILE.tmp"
    if [ $? -ne 0 ]; then
        log_message "ERROR" "Échec du nettoyage des anciennes configurations PAM"
        rm -f "$PAM_FILE.tmp"
        exit 1
    fi
    # Remplacer le fichier original
    mv "$PAM_FILE.tmp" "$PAM_FILE"
fi

# Ajouter la nouvelle configuration proprement
log_message "INFO" "Installation de la nouvelle configuration PAM..."
printf "# Notification Telegram pour su\n%s\n" "$PAM_LINE" >> "$PAM_FILE"

if [ $? -ne 0 ]; then
    log_message "ERROR" "Échec de l'installation de la configuration PAM"
    exit 1
fi
log_message "SUCCESS" "Configuration PAM installée"

# Nettoyage
log_message "INFO" "Nettoyage des anciennes sauvegardes..."
cd "$BACKUP_DIR" && ls -t telegram.* | tail -n +11 | xargs -r rm

# Message final
log_message "SUCCESS" "Mise à jour terminée avec succès!"
log_message "INFO" "Redémarrez votre session pour activer les changements"

exit 0