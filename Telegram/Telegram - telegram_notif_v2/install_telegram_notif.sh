#!/bin/bash

# Script d'installation automatique des notifications Telegram
# Version 2.0

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

# Création des répertoires nécessaires
BASE_DIR="/usr/local/bin/telegram/notif_connexion"
CONFIG_DIR="/etc/telegram/notif_connexion"
mkdir -p "$BASE_DIR" "$CONFIG_DIR"

# Création du groupe telegramnotif
if ! getent group telegramnotif > /dev/null; then
    groupadd telegramnotif
    log_message "INFO" "Groupe telegramnotif créé"
fi

# URL du dépôt
REPO_URL="https://raw.githubusercontent.com/Phips02/Bash/main/Telegram/Telegram%20-%20telegram_notif_v2"

# Création du dossier temporaire
TMP_DIR=$(mktemp -d)
log_message "INFO" "Création du dossier temporaire: $TMP_DIR"

# Téléchargement des scripts
log_message "INFO" "Téléchargement des scripts..."
for script in deploy_telegram.sh telegram.functions.sh telegram.sh; do
    if ! wget -q "${REPO_URL}/${script}" -O "${TMP_DIR}/${script}"; then
        log_message "ERROR" "Échec du téléchargement de ${script}"
        rm -rf "$TMP_DIR"
        exit 1
    fi
    chmod +x "${TMP_DIR}/${script}"
done

# Exécution du script de déploiement
log_message "INFO" "Lancement du script de déploiement..."
cd "$TMP_DIR"
chmod +x deploy_telegram.sh
./deploy_telegram.sh

# Configuration des permissions
log_message "INFO" "Configuration des permissions..."

# Permissions des scripts
chmod 755 "$BASE_DIR/telegram.sh"
chmod 755 "$BASE_DIR/telegram.functions.sh"
chown root:telegramnotif "$BASE_DIR"/*.sh

# Permissions du fichier de configuration
chmod 644 "$CONFIG_DIR/telegram.config"
chown root:telegramnotif "$CONFIG_DIR/telegram.config"

# Ajout de l'utilisateur courant au groupe
if [ -n "$SUDO_USER" ]; then
    usermod -a -G telegramnotif "$SUDO_USER"
    log_message "INFO" "Utilisateur $SUDO_USER ajouté au groupe telegramnotif"
fi

# Vérification de la présence dans /etc/profile
if ! grep -q "$BASE_DIR/telegram.sh" /etc/profile; then
    echo "# Notification Telegram pour connexions SSH" >> /etc/profile
    echo "$BASE_DIR/telegram.sh" >> /etc/profile
    log_message "INFO" "Script ajouté à /etc/profile"
fi

# Test de l'installation
log_message "INFO" "Test de l'installation..."
if "$BASE_DIR/telegram.sh"; then
    log_message "SUCCESS" "Test réussi"
else
    log_message "WARNING" "Le test a échoué, vérifiez les permissions"
fi

# Nettoyage
log_message "INFO" "Nettoyage..."
rm -rf "$TMP_DIR"

log_message "SUCCESS" "Installation terminée avec succès!"
log_message "INFO" "Déconnectez-vous et reconnectez-vous pour activer les notifications" 
