#!/bin/bash

###############################################################################
# Script de mise à jour des notifications Telegram
###############################################################################

# Fonction pour le logging avec horodatage, niveau et nom du script
function print_log() {
    local level="$1"
    local script="$2"
    local message="$3"
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] [$level] [$script] $message"
}

# Version du système
TELEGRAM_VERSION="3.33"

# Définition des chemins
BASE_DIR="/usr/local/bin/telegram/notif_connexion"
CONFIG_DIR="/etc/telegram/notif_connexion"
BACKUP_DIR="$CONFIG_DIR/backup"
SCRIPT_PATH="$BASE_DIR/telegram.sh"
CONFIG_PATH="$CONFIG_DIR/telegram.config"

print_log "INFO" "update.sh" "Exécution du script de mise à jour version $TELEGRAM_VERSION"

# Vérification des droits root
if [[ $EUID -ne 0 ]]; then
    print_log "ERROR" "update.sh" "Ce script doit être exécuté en tant que root"
    exit 1
fi

# Vérification des dépendances
for pkg in curl jq bash adduser; do
    print_log "INFO" "update.sh" "Vérification de $pkg..."
    if ! command -v "$pkg" &> /dev/null; then
        print_log "WARNING" "update.sh" "$pkg n'est pas installé. Installation en cours..."
        apt-get update && apt-get install -y "$pkg"
        if [ $? -ne 0 ]; then
            print_log "ERROR" "update.sh" "Échec de l'installation de $pkg"
            exit 1
        fi
        print_log "SUCCESS" "update.sh" "$pkg installé avec succès"
    fi
done

# Information sur la version actuelle
if [ -f "$CONFIG_PATH" ]; then
    CURRENT_VERSION=$(grep "TELEGRAM_VERSION=" "$CONFIG_PATH" | cut -d'"' -f2)
    print_log "INFO" "update.sh" "Version actuelle : $CURRENT_VERSION"
fi

# Création des répertoires nécessaires
mkdir -p "$BASE_DIR" "$CONFIG_DIR" "$BACKUP_DIR"

# Sauvegarde de la configuration existante
if [ -f "$CONFIG_PATH" ]; then
    BACKUP_DATE=$(date +%Y%m%d_%H%M%S)
    cp "$CONFIG_PATH" "$BACKUP_DIR/telegram.config.$BACKUP_DATE"
    cp "$SCRIPT_PATH" "$BACKUP_DIR/telegram.sh.$BACKUP_DATE"
    print_log "INFO" "update.sh" "Sauvegarde créée: $BACKUP_DATE"
fi

# Mise à jour des fichiers
print_log "INFO" "update.sh" "Téléchargement des nouveaux fichiers..."
REPO_URL="https://raw.githubusercontent.com/Phips02/Bash/main/Telegram/Telegram%20-%20telegram_notif_v2"

# Téléchargement et installation du script principal
wget -q "$REPO_URL/telegram.sh" -O "$SCRIPT_PATH"
if [ $? -ne 0 ]; then
    print_log "ERROR" "update.sh" "Échec du téléchargement du script"
    exit 1
fi

chmod 750 "$SCRIPT_PATH"
if [ $? -ne 0 ]; then
    print_log "ERROR" "update.sh" "Échec de la configuration des permissions"
    exit 1
fi

# Configuration PAM
PAM_FILE="/etc/pam.d/su"
PAM_LINE='PAM_LINE="session optional pam_exec.so seteuid /bin/bash -c "source '$CONFIG_DIR'/telegram.config 2>/dev/null && $SCRIPT_PATH""'

print_log "INFO" "update.sh" "Configuration PAM..."

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
print_log "SUCCESS" "update.sh" "Configuration PAM mise à jour"

# Nettoyage
print_log "INFO" "update.sh" "Nettoyage des anciennes sauvegardes..."
cd "$BACKUP_DIR" && ls -t telegram.* | tail -n +11 | xargs -r rm

# Message final
print_log "SUCCESS" "update.sh" "Mise à jour terminée avec succès!"
print_log "INFO" "update.sh" "Redémarrez votre session pour activer les changements"

# Configuration des permissions
print_log "INFO" "update.sh" "Configuration des permissions..."

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
    print_log "ERROR" "update.sh" "Échec de la configuration des permissions"
    exit 1
fi
print_log "SUCCESS" "update.sh" "Permissions configurées"

# Nettoyage et ajout au bash.bashrc
print_log "INFO" "update.sh" "Mise à jour de bash.bashrc..."

# Créer un fichier temporaire
TMP_BASHRC=$(mktemp)

# Sauvegarder les permissions actuelles
BASHRC_PERMS=$(stat -c %a /etc/bash.bashrc)

# Nettoyer les anciennes configurations
awk '
    /^# Notification Telegram/ { skip = 1; next }
    /^if.*telegram/ { skip = 1; next }
    /telegram.sh/ { skip = 1; next }
    skip == 1 && /^fi/ { skip = 0; next }
    skip != 1 { print }
' /etc/bash.bashrc > "$TMP_BASHRC"

# Ajouter la nouvelle configuration
echo '
# Notification Telegram pour connexions SSH et su
if [ -n "$PS1" ] && [ "$TERM" != "unknown" ] && [ -z "$PAM_TYPE" ]; then
    if [ -r '"$CONFIG_DIR"'/telegram.config ]; then
        source '"$CONFIG_DIR"'/telegram.config 2>/dev/null
        $SCRIPT_PATH &>/dev/null || true
    fi
fi' >> "$TMP_BASHRC"

# Installer la nouvelle configuration
mv "$TMP_BASHRC" /etc/bash.bashrc

# Restaurer les permissions correctes
chmod 644 /etc/bash.bashrc
chown root:root /etc/bash.bashrc

print_log "SUCCESS" "update.sh" "Configuration bash.bashrc mise à jour"

# Auto-destruction du script
print_log "INFO" "update.sh" "Auto-destruction du script..."
rm -f "$0" /tmp/update_telegram_notif.sh*
if [ $? -ne 0 ]; then
    print_log "WARNING" "update.sh" "Impossible de supprimer le script de mise à jour"
fi

print_log "SUCCESS" "update.sh" "Mise à jour terminée avec succès!"

exit 0
