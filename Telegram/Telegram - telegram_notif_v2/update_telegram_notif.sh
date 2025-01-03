#!/bin/bash

# Script de mise à jour des notifications Telegram
# Version 1.0

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

# Sauvegarder les informations importantes
if [ -f "/etc/telegram/notif_connexion/telegram.config" ]; then
    # Récupérer les valeurs actuelles
    export TELEGRAM_BOT_TOKEN=$(grep "TELEGRAM_BOT_TOKEN=" /etc/telegram/notif_connexion/telegram.config | cut -d'"' -f2)
    export TELEGRAM_CHAT_ID=$(grep "TELEGRAM_CHAT_ID=" /etc/telegram/notif_connexion/telegram.config | cut -d'"' -f2)
    log_message "INFO" "Sauvegarde de la configuration existante..."
else
    log_message "ERROR" "Configuration existante non trouvée. Installation requise."
    exit 1
fi

# Créer un dossier temporaire
TMP_DIR=$(mktemp -d)
log_message "INFO" "Création du dossier temporaire: $TMP_DIR"

# URL du dépôt
REPO_URL="https://raw.githubusercontent.com/Phips02/Bash/main/Telegram/Telegram%20-%20telegram_notif_v2"

# Téléchargement des nouveaux scripts
log_message "INFO" "Téléchargement des scripts..."
for script in deploy_telegram.sh telegram.functions.sh telegram.sh; do
    if ! wget -q "${REPO_URL}/${script}" -O "${TMP_DIR}/${script}"; then
        log_message "ERROR" "Échec du téléchargement de ${script}"
        rm -rf "$TMP_DIR"
        exit 1
    fi
    chmod +x "${TMP_DIR}/${script}"
done

# Exécuter le script de déploiement avec les variables exportées
log_message "INFO" "Exécution du script de déploiement..."
cd "$TMP_DIR"
./deploy_telegram.sh

# Nettoyage
log_message "INFO" "Nettoyage..."
rm -rf "$TMP_DIR"

log_message "SUCCESS" "Mise à jour terminée avec succès!"