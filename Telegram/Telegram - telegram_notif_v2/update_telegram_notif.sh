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
TELEGRAM_VERSION="3.48"

# Définition des chemins
BASE_DIR="/usr/local/bin/telegram/notif_connexion"
CONFIG_DIR="/etc/telegram/notif_connexion"
BACKUP_DIR="$CONFIG_DIR/backup"
SCRIPT_PATH="$BASE_DIR/telegram.sh"
CONFIG_PATH="$CONFIG_DIR/telegram.config"

print_log "INFO" "update.sh" "Exécution du script de mise à jour version $TELEGRAM_VERSION"

# Vérification de l'installation existante
print_log "INFO" "update.sh" "Vérification de l'installation..."

# Vérifier les fichiers et répertoires essentiels
REQUIRED_FILES=(
    "$BASE_DIR/telegram.sh"
    "$CONFIG_DIR/telegram.config"
)

REQUIRED_DIRS=(
    "$BASE_DIR"
    "$CONFIG_DIR"
)

# Vérifier les répertoires
for dir in "${REQUIRED_DIRS[@]}"; do
    if [ ! -d "$dir" ]; then
        print_log "ERROR" "update.sh" "Installation incomplète : répertoire manquant $dir"
        print_log "ERROR" "update.sh" "Veuillez d'abord installer le système avec install_telegram_notif.sh"
        exit 1
    fi
done

# Vérifier les fichiers
for file in "${REQUIRED_FILES[@]}"; do
    if [ ! -f "$file" ]; then
        print_log "ERROR" "update.sh" "Installation incomplète : fichier manquant $file"
        print_log "ERROR" "update.sh" "Veuillez d'abord installer le système avec install_telegram_notif.sh"
        exit 1
    fi
done

print_log "SUCCESS" "update.sh" "Installation existante détectée"

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
#PAM_LINE='PAM_LINE="session optional pam_exec.so seteuid /bin/bash -c "source '$CONFIG_DIR'/telegram.config 2>/dev/null && $SCRIPT_PATH""'

PAM_LINE="session optional pam_exec.so seteuid $BASE_DIR/telegram_wrapper.sh"

if grep -q "session.*telegram" "$PAM_FILE"; then
    sed -i '/Notification Telegram/,/telegram/d' "$PAM_FILE"
fi

printf "# Notification Telegram pour su/sudo uniquement\n%s\n" "$PAM_LINE" >> "$PAM_FILE"


# Mise à jour des configurations système
print_log "INFO" "update.sh" "Mise à jour des configurations système..."

# 1. Configuration PAM
print_log "INFO" "update.sh" "Configuration PAM..."
TMP_PAM=$(mktemp)

# Nettoyer et mettre à jour PAM
awk '
    BEGIN { prev_empty = 0 }
    /^[[:space:]]*#.*[Tt]elegram/ { next }
    /telegram/ { next }
    /^[[:space:]]*#$/ { next }
    {
        if ($0 ~ /^[[:space:]]*$/) {
            if (!prev_empty) { prev_empty = 1 }
        } else {
            printf "%s\n", $0
            prev_empty = 0
        }
    }
' "$PAM_FILE" > "$TMP_PAM"

printf "# Notification Telegram pour su\n%s\n" "$PAM_LINE" >> "$TMP_PAM"
mv "$TMP_PAM" "$PAM_FILE"

# 2. Configuration bash.bashrc
print_log "INFO" "update.sh" "Configuration bash.bashrc..."
TMP_BASHRC=$(mktemp)

# Nettoyer et mettre à jour bash.bashrc
awk '
    BEGIN { empty_lines = 0 }
    /^# Notification Telegram/ { skip = 1; next }
    /^if.*telegram/ { skip = 1; next }
    /telegram.sh/ { skip = 1; next }
    skip == 1 && /^fi/ { skip = 0; next }
    !skip {
        if ($0 ~ /^[[:space:]]*$/) {
            empty_lines++
            if (empty_lines <= 1) print
        } else {
            empty_lines = 0
            print
        }
    }
' /etc/bash.bashrc > "$TMP_BASHRC"

# Installation du wrapper script
print_log "INFO" "update.sh" "Installation du wrapper script..."
cat > "$BASE_DIR/telegram_wrapper.sh" << 'EOF'
#!/bin/bash
source /etc/telegram/notif_connexion/telegram.config 2>/dev/null
/usr/local/bin/telegram/notif_connexion/telegram.sh "$@"
EOF

chmod 4755 "$BASE_DIR/telegram_wrapper.sh"  # setuid root
chown root:root "$BASE_DIR/telegram_wrapper.sh"

# Modification de bash.bashrc
echo '
# Notification Telegram pour connexions SSH et su
if [ -n "$SSH_CONNECTION" ] && [ -z "$PAM_TYPE" ]; then
    '"$BASE_DIR"'/telegram_wrapper.sh &>/dev/null || true
fi' >> "$TMP_BASHRC"

mv "$TMP_BASHRC" /etc/bash.bashrc
chmod 644 /etc/bash.bashrc
chown root:root /etc/bash.bashrc

print_log "SUCCESS" "update.sh" "Configurations système mises à jour"

# Configuration des permissions
print_log "INFO" "update.sh" "Configuration des permissions..."

# Permissions des répertoires
chmod 750 "$BASE_DIR"           # rwxr-x--- - Accès restreint au groupe
chmod 750 "$CONFIG_DIR"         # rwxr-x--- - Accès restreint au groupe
chmod 750 "$BACKUP_DIR"         # rwxr-x--- - Accès restreint au groupe

# Permissions des fichiers
chmod 640 "$CONFIG_PATH"        # rw-r----- - Lecture groupe uniquement
chmod 750 "$SCRIPT_PATH"        # rwxr-x--- - Exécution groupe uniquement

# Propriétaire et groupe
chown -R root:telegramnotif "$BASE_DIR" "$CONFIG_DIR"
chown root:telegramnotif "$CONFIG_PATH"  # Config accessible par le groupe telegramnotif

# Réappliquer l'attribut immutable
chattr +i "$CONFIG_PATH"

if [ $? -ne 0 ]; then
    print_log "ERROR" "update.sh" "Échec de la configuration des permissions"
    exit 1
fi
print_log "SUCCESS" "update.sh" "Permissions configurées"

# Nettoyage des sauvegardes
print_log "INFO" "update.sh" "Conservation de la dernière sauvegarde uniquement"
if [ -d "$BACKUP_DIR" ]; then
    # Nettoyage des fichiers de configuration
    cd "$BACKUP_DIR" && ls -t telegram.config.* 2>/dev/null | tail -n +2 | xargs -r rm
    
    # Nettoyage des scripts
    cd "$BACKUP_DIR" && ls -t telegram.sh.* 2>/dev/null | tail -n +2 | xargs -r rm
fi

# Auto-destruction du script
print_log "INFO" "update.sh" "Auto-destruction du script..."
rm -f "$0" /tmp/update_telegram_notif.sh*
if [ $? -ne 0 ]; then
    print_log "WARNING" "update.sh" "Impossible de supprimer le script de mise à jour"
fi

# Message final unique
print_log "SUCCESS" "update.sh" "Mise à jour version $TELEGRAM_VERSION terminée avec succès"
echo "" # Ajout d'une ligne vide pour un retour propre

exit 0
