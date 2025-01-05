#!/bin/bash

###############################################################################
# Script d'installation automatique des notifications Telegram
###############################################################################

# Version du système
TELEGRAM_VERSION="3.29"

# Définition des chemins
BASE_DIR="/usr/local/bin/telegram/notif_connexion"
CONFIG_DIR="/etc/telegram/notif_connexion"
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

# Vérification et installation des dépendances
for pkg in curl jq bash adduser; do
    log_message "INFO" "Vérification de $pkg..."
    if ! command -v "$pkg" &> /dev/null; then
        log_message "WARNING" "$pkg n'est pas installé. Installation en cours..."
        apt-get update && apt-get install -y "$pkg"
        if [ $? -ne 0 ]; then
            log_message "ERROR" "Échec de l'installation de $pkg"
            exit 1
        fi
        log_message "SUCCESS" "$pkg installé avec succès"
    fi
done

# Création des répertoires nécessaires
mkdir -p "$BASE_DIR" "$CONFIG_DIR"
if [ $? -ne 0 ]; then
    log_message "ERROR" "Échec de la création des répertoires"
    exit 1
fi

# Création du groupe telegramnotif
if ! getent group telegramnotif > /dev/null; then
    groupadd telegramnotif
    if [ $? -ne 0 ]; then
        log_message "ERROR" "Échec de la création du groupe"
        exit 1
    fi
    log_message "SUCCESS" "Groupe telegramnotif créé"
fi

# Ajout de l'utilisateur au groupe si nécessaire
if ! groups "$USER" | grep -q "telegramnotif"; then
    usermod -a -G telegramnotif "$USER"
    if [ $? -ne 0 ]; then
        log_message "WARNING" "Impossible d'ajouter l'utilisateur au groupe telegramnotif"
    else
        log_message "SUCCESS" "Utilisateur ajouté au groupe telegramnotif"
    fi
fi

# Validation du TOKEN Telegram
if [ -z "$TELEGRAM_BOT_TOKEN" ]; then
    while true; do
        read -p "Entrez votre TOKEN Telegram : " TELEGRAM_BOT_TOKEN
        if [[ $TELEGRAM_BOT_TOKEN =~ ^[0-9]+:[a-zA-Z0-9_-]+$ ]]; then
            break
        else
            log_message "ERROR" "Format de TOKEN invalide. Format attendu: 123456789:ABCdefGHIjklMNOpqrsTUVwxyz"
        fi
    done
fi

# Validation du Chat ID
if [ -z "$TELEGRAM_CHAT_ID" ]; then
    while true; do
        read -p "Entrez votre Chat ID Telegram : " TELEGRAM_CHAT_ID
        if [[ $TELEGRAM_CHAT_ID =~ ^-?[0-9]+$ ]]; then
            break
        else
            log_message "ERROR" "Format de Chat ID invalide. Doit être un nombre"
        fi
    done
fi

# Téléchargement et installation des fichiers
REPO_URL="https://raw.githubusercontent.com/Phips02/Bash/main/Telegram/Telegram%20-%20telegram_notif_v2"

log_message "INFO" "Téléchargement de telegram.sh..."
wget -q "${REPO_URL}/telegram.sh" -O "${BASE_DIR}/telegram.sh"
if [ $? -ne 0 ]; then
    log_message "ERROR" "Échec du téléchargement du script"
    exit 1
fi

chmod +x "${BASE_DIR}/telegram.sh"
if [ $? -ne 0 ]; then
    log_message "ERROR" "Échec de l'attribution des droits d'exécution"
    exit 1
fi

# Création du fichier de configuration
log_message "INFO" "Création du fichier de configuration..."
cat > "$CONFIG_DIR/telegram.config" << EOF
###############################################################################
# Configuration Telegram pour les notifications de connexion
# Version 3.5
###############################################################################

# Configuration du bot
TELEGRAM_BOT_TOKEN="${TELEGRAM_BOT_TOKEN}"
TELEGRAM_CHAT_ID="${TELEGRAM_CHAT_ID}"

# Chemins système
BASE_DIR="${BASE_DIR}"
CONFIG_DIR="${CONFIG_DIR}"
SCRIPT_PATH="\$BASE_DIR/telegram.sh"
CONFIG_PATH="\$CONFIG_DIR/telegram.config"

# Paramètres
LOG_LEVEL="INFO"
CURL_TIMEOUT=10
DATE_FORMAT="%Y-%m-%d %H:%M:%S"

# Export des variables
export TELEGRAM_BOT_TOKEN TELEGRAM_CHAT_ID
export BASE_DIR CONFIG_DIR SCRIPT_PATH CONFIG_PATH
export LOG_LEVEL CURL_TIMEOUT DATE_FORMAT
EOF

if [ $? -ne 0 ]; then
    log_message "ERROR" "Échec de la création du fichier de configuration"
    exit 1
fi

# Configuration PAM
PAM_FILE="/etc/pam.d/su"
PAM_LINE="session optional pam_exec.so seteuid /bin/bash -c 'source $CONFIG_DIR/telegram.config 2>/dev/null && $SCRIPT_PATH'"

log_message "INFO" "Configuration PAM..."

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
log_message "SUCCESS" "Configuration PAM mise à jour"

# Configuration des permissions
log_message "INFO" "Configuration des permissions..."
chmod 640 "$CONFIG_DIR/telegram.config"
if [ $? -ne 0 ]; then
    log_message "ERROR" "Échec de la modification des permissions du fichier de configuration"
    exit 1
fi

chmod 750 "$BASE_DIR/telegram.sh"
if [ $? -ne 0 ]; then
    log_message "ERROR" "Échec de la modification des permissions du script"
    exit 1
fi

chown root:telegramnotif "$CONFIG_DIR/telegram.config"
if [ $? -ne 0 ]; then
    log_message "ERROR" "Échec de la modification du propriétaire du fichier de configuration"
    exit 1
fi

chown root:telegramnotif "$BASE_DIR/telegram.sh"
if [ $? -ne 0 ]; then
    log_message "ERROR" "Échec de la modification du propriétaire du script"
    exit 1
fi

# Configuration système
log_message "INFO" "Configuration du système..."

# Ajout au bash.bashrc
if ! grep -q "\$SCRIPT_PATH" /etc/bash.bashrc; then
    echo '
# Notification Telegram pour connexions SSH et su
if [ -n "$PS1" ] && [ "$TERM" != "unknown" ] && [ -z "$PAM_TYPE" ]; then
    source '"$CONFIG_DIR"'/telegram.config
    $SCRIPT_PATH &>/dev/null
fi' >> /etc/bash.bashrc
    chmod 644 /etc/bash.bashrc
    chown root:root /etc/bash.bashrc
    if [ $? -ne 0 ]; then
        log_message "ERROR" "Échec de la configuration de bash.bashrc"
        exit 1
    fi
fi

# Test de l'installation
log_message "INFO" "Test de l'installation..."
"$BASE_DIR/telegram.sh" silent &
test_pid=$!

log_message "INFO" "Exécution du script d'installation version $TELEGRAM_VERSION"
log_message "SUCCESS" "Installation réussie!"

# Auto-destruction du script
log_message "INFO" "Auto-destruction du script..."
rm -f "$0"
if [ $? -ne 0 ]; then
    log_message "WARNING" "Impossible de supprimer le script d'installation"
fi

# Attendre la fin du test silencieusement
wait $test_pid &>/dev/null

# Message final
echo ""
log_message "INFO" "Déconnectez-vous et reconnectez-vous pour activer les notifications"
echo ""