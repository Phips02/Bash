#!/bin/bash

###############################################################################
# Script de mise à jour des notifications Telegram
###############################################################################

# Fonction pour le logging avec niveau et composant
function print_log() {
    local level="$1"
    local component="$2"
    local message="$3"
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] [$level] [$component] $message"
}

# Version du système
TELEGRAM_VERSION="3.21"

# Définition des chemins
BASE_DIR="/usr/local/bin/telegram/notif_connexion"
CONFIG_DIR="/etc/telegram/notif_connexion"
BACKUP_DIR="$CONFIG_DIR/backup"
SCRIPT_PATH="$BASE_DIR/telegram.sh"
CONFIG_PATH="$CONFIG_DIR/telegram.config"

print_log "info" "update" "Exécution du script de mise à jour version $TELEGRAM_VERSION"

# Vérification des droits root
if [[ $EUID -ne 0 ]]; then
    print_log "error" "update" "Ce script doit être exécuté en tant que root"
    exit 1
fi

# Information sur la version actuelle
if [ -f "$CONFIG_PATH" ]; then
    CURRENT_VERSION=$(grep "TELEGRAM_VERSION=" "$CONFIG_PATH" | cut -d'"' -f2)
    print_log "info" "update" "Version actuelle : $CURRENT_VERSION"
fi

# Création des répertoires nécessaires
mkdir -p "$BASE_DIR" "$CONFIG_DIR" "$BACKUP_DIR"

# Sauvegarde de la configuration existante
if [ -f "$CONFIG_PATH" ]; then
    BACKUP_DATE=$(date +%Y%m%d_%H%M%S)
    cp "$CONFIG_PATH" "$BACKUP_DIR/telegram.config.$BACKUP_DATE"
    cp "$SCRIPT_PATH" "$BACKUP_DIR/telegram.sh.$BACKUP_DATE"
    print_log "info" "update" "Sauvegarde créée: $BACKUP_DATE"
fi

# Mise à jour des fichiers
print_log "info" "update" "Téléchargement des nouveaux fichiers..."
REPO_URL="https://raw.githubusercontent.com/Phips02/Bash/main/Telegram/Telegram%20-%20telegram_notif_v2"

# Téléchargement et installation du script principal
wget -q "$REPO_URL/telegram.sh" -O "$SCRIPT_PATH"
if [ $? -ne 0 ]; then
    print_log "error" "update" "Échec du téléchargement du script"
    exit 1
fi

chmod 750 "$SCRIPT_PATH"
if [ $? -ne 0 ]; then
    print_log "error" "update" "Échec de la configuration des permissions"
    exit 1
fi

# Configuration PAM
PAM_FILE="/etc/pam.d/su"
PAM_LINE='PAM_LINE="session optional pam_exec.so seteuid /bin/bash -c "source '$CONFIG_DIR'/telegram.config 2>/dev/null && $SCRIPT_PATH""'

print_log "info" "update" "Configuration PAM..."

# Créer un fichier temporaire
TMP_PAM=$(mktemp)

# 1. Copier le contenu existant en préservant la structure mais en filtrant Telegram
awk '
    BEGIN { prev_empty = 0 }
    /^[[:space:]]*#.*[Tt]elegram/ { next }      # Ignorer les commentaires Telegram
    /telegram/ { next }                          # Ignorer les lignes contenant telegram
    /^[[:space:]]*#$/ { next }                  # Ignorer les lignes avec juste un #
    {
        if ($0 ~ /^[[:space:]]*$/) {            # Ligne vide
            if (!prev_empty) {
                prev_empty = 1
            }
        } else {                                 # Ligne non vide
            printf "%s\n", $0
            prev_empty = 0
        }
    }
' "$PAM_FILE" > "$TMP_PAM"

# 2. Ajouter la nouvelle configuration
printf "# Notification Telegram pour su\n%s\n" "$PAM_LINE" >> "$TMP_PAM"

# 3. Installer la nouvelle configuration
mv "$TMP_PAM" "$PAM_FILE"
print_log "success" "update" "Configuration PAM mise à jour"

# Nettoyage
print_log "info" "update" "Nettoyage des anciennes sauvegardes..."
cd "$BACKUP_DIR" && ls -t telegram.* | tail -n +11 | xargs -r rm

# Message final
print_log "success" "update" "Mise à jour terminée avec succès!"
print_log "info" "update" "Redémarrez votre session pour activer les changements"

# Configuration des permissions
print_log "info" "update" "Configuration des permissions..."

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
    print_log "error" "update" "Échec de la configuration des permissions"
    exit 1
fi
print_log "success" "update" "Permissions configurées"

# Ajout au bash.bashrc
if ! grep -q "\$SCRIPT_PATH" /etc/bash.bashrc; then
    echo '
# Notification Telegram pour connexions SSH et su
if [ -n "$PS1" ] && [ "$TERM" != "unknown" ] && [ -z "$PAM_TYPE" ]; then
    if [ -r '"$CONFIG_DIR"'/telegram.config ]; then
        source '"$CONFIG_DIR"'/telegram.config 2>/dev/null
        $SCRIPT_PATH &>/dev/null || true
    fi
fi' >> /etc/bash.bashrc
fi

# Auto-destruction du script
print_log "info" "update" "Auto-destruction du script..."
rm -f "$0" /tmp/update_telegram_notif.sh*
if [ $? -ne 0 ]; then
    print_log "warning" "update" "Impossible de supprimer le script de mise à jour"
fi

exit 0