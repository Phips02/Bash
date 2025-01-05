#!/bin/bash

###############################################################################
# Script de mise à jour des notifications Telegram
###############################################################################

# Version du système
TELEGRAM_VERSION="3.4"

# Définition des chemins
BASE_DIR="/usr/local/bin/telegram/notif_connexion"
CONFIG_DIR="/etc/telegram/notif_connexion"
BACKUP_DIR="$CONFIG_DIR/backup"
SCRIPT_PATH="$BASE_DIR/telegram.sh"
CONFIG_PATH="$CONFIG_DIR/telegram.config"

# Vérification de la version actuelle
if [ -f "$CONFIG_PATH" ]; then
    CURRENT_VERSION=$(grep "TELEGRAM_VERSION=" "$CONFIG_PATH" | cut -d'"' -f2)
    log_message "INFO" "Version actuelle : $CURRENT_VERSION"
fi

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
PAM_FILE="/etc/pam.d/su"
PAM_LINE="session optional pam_exec.so seteuid /bin/bash -c \"source $CONFIG_DIR/telegram.config 2>/dev/null && \$SCRIPT_PATH\""

log_message "INFO" "Configuration PAM..."

# Créer un fichier temporaire
TMP_PAM=$(mktemp)

# Copier toutes les lignes sauf celles contenant telegram
grep -v "telegram" "$PAM_FILE" > "$TMP_PAM"

# Ajouter la nouvelle configuration
echo "# Notification Telegram pour su" >> "$TMP_PAM"
echo "$PAM_LINE" >> "$TMP_PAM"

# Remplacer le fichier original
mv "$TMP_PAM" "$PAM_FILE"

log_message "SUCCESS" "Configuration PAM mise à jour"

# Nettoyage
log_message "INFO" "Nettoyage des anciennes sauvegardes..."
cd "$BACKUP_DIR" && ls -t telegram.* | tail -n +11 | xargs -r rm

# Message final
log_message "SUCCESS" "Mise à jour terminée avec succès!"
log_message "INFO" "Redémarrez votre session pour activer les changements"

# Vérification de la nouvelle version
log_message "INFO" "Vérification de la version installée..."
INSTALLED_VERSION=$(grep "TELEGRAM_VERSION=" "$CONFIG_PATH" | cut -d'"' -f2)
if [ "$INSTALLED_VERSION" = "$TELEGRAM_VERSION" ]; then
    log_message "SUCCESS" "Version $INSTALLED_VERSION installée avec succès"
    if [ -n "$CURRENT_VERSION" ] && [ "$CURRENT_VERSION" != "$INSTALLED_VERSION" ]; then
        log_message "INFO" "Mise à jour effectuée : $CURRENT_VERSION -> $INSTALLED_VERSION"
    fi
else
    log_message "WARNING" "Version installée ($INSTALLED_VERSION) différente de la version attendue ($TELEGRAM_VERSION)"
fi

# Configuration des permissions
log_message "INFO" "Configuration des permissions..."

# Permissions des répertoires
chmod 755 "$BASE_DIR"
chmod 755 "$CONFIG_DIR"
chmod 755 "$BACKUP_DIR"

# Permissions des fichiers
chmod 644 "$CONFIG_PATH"  # Lecture pour tous
chmod 755 "$SCRIPT_PATH"  # Exécution pour tous

# Propriétaire et groupe
chown -R root:root "$BASE_DIR" "$CONFIG_DIR"
chmod g+rx "$CONFIG_DIR"  # Lecture et exécution pour le groupe
chmod o+rx "$CONFIG_DIR"  # Lecture et exécution pour les autres

if [ $? -ne 0 ]; then
    log_message "ERROR" "Échec de la configuration des permissions"
    exit 1
fi
log_message "SUCCESS" "Permissions configurées"

# Ajout au bash.bashrc
if ! grep -q "\$SCRIPT_PATH" /etc/bash.bashrc; then
    echo '
# Notification Telegram pour connexions SSH et su
if [ -n "$PS1" ] && [ "$TERM" != "unknown" ]; then
    if [ -r '"$CONFIG_DIR"'/telegram.config ]; then
        source '"$CONFIG_DIR"'/telegram.config 2>/dev/null
        $SCRIPT_PATH &>/dev/null || true
    fi
fi' >> /etc/bash.bashrc
fi

exit 0