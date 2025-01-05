#!/bin/bash

###############################################################################
# Script d'installation automatique des notifications Telegram
###############################################################################

# Version du système
TELEGRAM_VERSION="3.9"

# Définition des chemins
BASE_DIR="/usr/local/bin/telegram/notif_connexion"
CONFIG_DIR="/etc/telegram/notif_connexion"

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
for pkg in curl jq bash; do
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

# Gestion du hostname
current_hostname=$(hostname)
log_message "INFO" "Hostname actuel du serveur : $current_hostname"

while true; do
    read -p "Voulez-vous modifier le hostname ? (o/n) : " change_hostname
    case $change_hostname in
        [oO]*)
            while true; do
                read -p "Entrez le nouveau hostname : " new_hostname
                if [[ $new_hostname =~ ^[a-zA-Z0-9-]+$ ]]; then
                    # Sauvegarde du hostname actuel
                    cp /etc/hostname /etc/hostname.bak
                    if [ $? -ne 0 ]; then
                        log_message "ERROR" "Échec de la sauvegarde du hostname"
                        continue
                    fi
                    
                    # Modification du hostname
                    echo "$new_hostname" > /etc/hostname
                    if [ $? -ne 0 ]; then
                        log_message "ERROR" "Échec de la modification du hostname"
                        continue
                    fi
                    
                    # Mise à jour des hosts
                    sed -i "s/$current_hostname/$new_hostname/g" /etc/hosts
                    if [ $? -ne 0 ]; then
                        log_message "ERROR" "Échec de la mise à jour des hosts"
                        continue
                    fi
                    
                    # Application du nouveau hostname
                    hostnamectl set-hostname "$new_hostname"
                    if [ $? -ne 0 ]; then
                        log_message "ERROR" "Échec de l'application du nouveau hostname"
                        continue
                    fi
                    
                    HOSTNAME=$new_hostname
                    export HOSTNAME
                    log_message "SUCCESS" "Hostname modifié avec succès : $new_hostname"
                    break
                else
                    log_message "ERROR" "Format de hostname invalide. Utilisez uniquement des lettres, chiffres et tirets"
                fi
            done
            break
            ;;
        [nN]*)
            HOSTNAME=$current_hostname
            break
            ;;
        *)
            log_message "ERROR" "Répondez par 'o' pour oui ou 'n' pour non"
            ;;
    esac
done

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
# Version 3.4
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
if [ -n "$PS1" ] && [ "$TERM" != "unknown" ]; then
    source '"$CONFIG_DIR"'/telegram.config
    $SCRIPT_PATH &>/dev/null
fi' >> /etc/bash.bashrc
    if [ $? -ne 0 ]; then
        log_message "ERROR" "Échec de la configuration de bash.bashrc"
        exit 1
    fi
fi

# Configuration PAM
if ! grep -q "session.*telegram.sh" /etc/pam.d/su; then
    echo "# Notification Telegram pour su
session optional pam_exec.so seteuid /bin/bash -c \"source $CONFIG_DIR/telegram.config 2>/dev/null && \$SCRIPT_PATH\"" >> /etc/pam.d/su
    if [ $? -ne 0 ]; then
        log_message "ERROR" "Échec de la configuration PAM"
        exit 1
    fi
fi

# Test de l'installation
log_message "INFO" "Test de l'installation..."
"$BASE_DIR/telegram.sh"
if [ $? -ne 0 ]; then
    log_message "ERROR" "Le test a échoué, vérifiez la configuration"
    exit 1
fi

log_message "INFO" "Exécution du script d'installation version $TELEGRAM_VERSION"
log_message "SUCCESS" "Installation réussie!"
log_message "INFO" "Déconnectez-vous et reconnectez-vous pour activer les notifications"

# Auto-destruction du script
log_message "INFO" "Auto-destruction du script..."
rm -f "$0"
if [ $? -ne 0 ]; then
    log_message "WARNING" "Impossible de supprimer le script d'installation"
fi

exit 0



