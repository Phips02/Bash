#!/bin/bash

# Script d'installation automatique des notifications Telegram
# Version 1.0

# Fonction de logging
function log_message() {
    local level="$1"
    local message="$2"
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] [$level] $message"
}

# Vérification que le script est exécuté en tant que root
if [[ $EUID -ne 0 ]]; then
    log_message "ERROR" "Ce script doit être exécuté en tant que root."
    exit 1
fi

# Vérification des arguments
if [ "$#" -ne 2 ]; then
    log_message "ERROR" "Usage: $0 <TELEGRAM_BOT_TOKEN> <TELEGRAM_CHAT_ID>"
    log_message "INFO" "Exemple: $0 123456789:ABCdefGHIjklMNOpqrsTUVwxyz -123456789"
    exit 1
fi

TELEGRAM_BOT_TOKEN="$1"
TELEGRAM_CHAT_ID="$2"

# URL du dépôt (à modifier selon votre dépôt)
REPO_URL="https://raw.githubusercontent.com/Phips02/Bash/main/Telegram%20-%20telegram_notif_v2"

# Création du dossier temporaire
TMP_DIR=$(mktemp -d)
log_message "INFO" "Création du dossier temporaire: $TMP_DIR"

# Téléchargement du script de déploiement
log_message "INFO" "Téléchargement du script de déploiement..."
if ! wget -q "${REPO_URL}/deploy_telegram.sh" -O "${TMP_DIR}/deploy_telegram.sh"; then
    log_message "ERROR" "Échec du téléchargement du script"
    rm -rf "$TMP_DIR"
    exit 1
fi

# Rendre le script exécutable
chmod +x "${TMP_DIR}/deploy_telegram.sh"

# Export des variables pour le script de déploiement
export TELEGRAM_BOT_TOKEN
export TELEGRAM_CHAT_ID

# Exécution du script de déploiement
log_message "INFO" "Lancement du script de déploiement..."
"${TMP_DIR}/deploy_telegram.sh"

# Nettoyage
log_message "INFO" "Nettoyage..."
rm -rf "$TMP_DIR"

log_message "SUCCESS" "Installation terminée avec succès!" 