#!/bin/bash

# Redirection des erreurs de source vers /dev/null
exec 2>/dev/null

###############################################################################
# Script de mise à jour des notifications Telegram
# Version 3.6
###############################################################################

# Fonction pour le logging avec horodatage et niveau
function log_message() {
    local level="$1"
    local message="$2"
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] [$level] $message"
}

# Vérification de la version
SCRIPT_VERSION="3.6"
log_message "INFO" "Démarrage du script de mise à jour version $SCRIPT_VERSION"

# Vérification de la version en ligne
ONLINE_VERSION=$(wget -qO- "https://raw.githubusercontent.com/Phips02/Bash/main/Telegram/Telegram%20-%20telegram_notif_v2/update_telegram_notif.sh" | grep -m1 "Version" | cut -d" " -f3)
if [ -n "$ONLINE_VERSION" ] && [ "$ONLINE_VERSION" != "$SCRIPT_VERSION" ]; then
    log_message "WARNING" "Une nouvelle version est disponible: $ONLINE_VERSION (version actuelle: $SCRIPT_VERSION)"
    read -p "Voulez-vous continuer avec la version actuelle ? (o/N) " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Oo]$ ]]; then
        log_message "INFO" "Mise à jour annulée. Veuillez télécharger la dernière version."
        exit 1
    fi
fi

# Définition des chemins
BASE_DIR="/usr/local/bin/telegram/notif_connexion"
CONFIG_DIR="/etc/telegram/notif_connexion"
BACKUP_DIR="$CONFIG_DIR/backup"
SCRIPT_PATH="$BASE_DIR/telegram.sh"
CONFIG_PATH="$CONFIG_DIR/telegram.config"

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

# Configuration PAM avec sécurité
log_message "INFO" "Vérification de la configuration PAM..."
if grep -q "telegram" /etc/pam.d/su; then
    log_message "INFO" "Nettoyage de l'ancienne configuration PAM..."
    if ! execute_command "sed -i '/telegram/d' /etc/pam.d/su" "nettoyage de la configuration PAM"; then
        exit 1
    fi
fi

# Ajout de la nouvelle configuration si nécessaire
if ! grep -q "session.*telegram.sh" /etc/pam.d/su; then
    log_message "INFO" "Installation de la configuration PAM..."
    if ! execute_command "echo '# Notification Telegram pour su
session optional pam_exec.so seteuid /bin/bash -c \"source $CONFIG_DIR/telegram.config 2>/dev/null && \$SCRIPT_PATH\"' >> /etc/pam.d/su" "configuration de PAM"; then
        exit 1
    fi
    log_message "SUCCESS" "Configuration PAM installée"
else
    log_message "INFO" "Configuration PAM déjà présente"
fi

# Nettoyage
log_message "INFO" "Nettoyage des anciennes sauvegardes..."
cd "$BACKUP_DIR" && ls -t telegram.* | tail -n +11 | xargs -r rm

# Message final
log_message "SUCCESS" "Mise à jour terminée avec succès!"
log_message "INFO" "Redémarrez votre session pour activer les changements"

exit 0