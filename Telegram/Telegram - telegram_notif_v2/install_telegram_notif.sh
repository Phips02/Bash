#!/bin/bash

# Script d'installation automatique des notifications Telegram
# Version 3.0

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

# Fonction pour vérifier et installer les dépendances
function check_and_install_dependency() {
    local pkg_name="$1"
    local pkg_cmd="$2"
    log_message "INFO" "Vérification de $pkg_name..."
    if ! command -v "$pkg_cmd" &> /dev/null; then
        log_message "WARNING" "$pkg_cmd n'est pas installé. Installation en cours..."
        if apt-get update && apt-get install -y "$pkg_name"; then
            log_message "SUCCESS" "$pkg_name installé avec succès"
        else
            log_message "ERROR" "Échec de l'installation de $pkg_name"
            exit 1
        fi
    else
        log_message "INFO" "$pkg_cmd est déjà installé."
    fi
}

# Vérification des dépendances
check_and_install_dependency "curl" "curl"
check_and_install_dependency "jq" "jq"
check_and_install_dependency "bash" "bash"

# Création des répertoires nécessaires
BASE_DIR="/usr/local/bin/telegram/notif_connexion"
CONFIG_DIR="/etc/telegram/notif_connexion"
mkdir -p "$BASE_DIR" "$CONFIG_DIR"

# Création du groupe telegramnotif
if ! getent group telegramnotif > /dev/null; then
    groupadd telegramnotif
    log_message "INFO" "Groupe telegramnotif créé"
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
            log_message "ERROR" "Format de Chat ID invalide. Doit être un nombre."
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
                    cp /etc/hostname /etc/hostname.bak
                    echo "$new_hostname" > /etc/hostname
                    sed -i "s/$current_hostname/$new_hostname/g" /etc/hosts
                    hostnamectl set-hostname "$new_hostname"
                    HOSTNAME=$new_hostname
                    export HOSTNAME
                    log_message "SUCCESS" "Hostname modifié avec succès : $new_hostname"
                    break
                else
                    log_message "ERROR" "Format de hostname invalide. Utilisez uniquement des lettres, chiffres et tirets."
                fi
            done
            break
            ;;
        [nN]*)
            HOSTNAME=$current_hostname
            break
            ;;
        *)
            log_message "ERROR" "Répondez par 'o' pour oui ou 'n' pour non."
            ;;
    esac
done

# Créer un dossier temporaire
TMP_DIR=$(mktemp -d)
log_message "INFO" "Création du dossier temporaire: $TMP_DIR"

# URL du dépôt
REPO_URL="https://raw.githubusercontent.com/Phips02/Bash/main/Telegram/Telegram%20-%20telegram_notif_v2"

# Téléchargement du script telegram.sh
log_message "INFO" "Téléchargement de telegram.sh..."
if ! wget -q "${REPO_URL}/telegram.sh" -O "${BASE_DIR}/telegram.sh"; then
    log_message "ERROR" "Échec du téléchargement de telegram.sh"
    rm -rf "$TMP_DIR"
    exit 1
fi
chmod +x "${BASE_DIR}/telegram.sh"

# Création du fichier telegram.config
cat <<EOF > "$CONFIG_DIR/telegram.config"
# Configuration Telegram
# Version 3.0
# Fichier : /etc/telegram/notif_connexion/telegram.config

TELEGRAM_BOT_TOKEN="${TELEGRAM_BOT_TOKEN}"
TELEGRAM_CHAT_ID="${TELEGRAM_CHAT_ID}"
EOF

# Configuration des permissions
log_message "INFO" "Configuration des permissions..."
chmod 640 "$CONFIG_DIR/telegram.config"
chmod 750 "$BASE_DIR/telegram.sh"
chown root:telegramnotif "$CONFIG_DIR/telegram.config"
chown root:telegramnotif "$BASE_DIR/telegram.sh"

# Ajout au bash.bashrc
if ! grep -q "\$SCRIPT_PATH" /etc/bash.bashrc; then
    log_message "INFO" "Configuration de la notification automatique..."
    echo "
# Notification Telegram pour connexions SSH et su
if [ -n \"\$PS1\" ] && [ \"\$TERM\" != \"unknown\" ]; then
    source $CONFIG_DIR/telegram.config
    \$SCRIPT_PATH &>/dev/null
fi" >> /etc/bash.bashrc
fi

# Ajout de la configuration PAM pour su
log_message "INFO" "Configuration de PAM pour su..."
if ! grep -q "session.*telegram.sh" /etc/pam.d/su; then
    echo "# Notification Telegram pour su
session optional pam_exec.so seteuid source $CONFIG_DIR/telegram.config && \$SCRIPT_PATH" >> /etc/pam.d/su
fi

# Test de l'installation
log_message "INFO" "Test de l'installation..."
if "$BASE_DIR/telegram.sh"; then
    log_message "SUCCESS" "Installation réussie!"
else
    log_message "ERROR" "Le test a échoué, vérifiez la configuration"
fi

# Auto-destruction du script de déploiement
log_message "INFO" "Auto-destruction du script de déploiement..."
rm -f "$0" 

# Message final
log_message "INFO" "Déconnectez-vous et reconnectez-vous pour activer les notifications"



