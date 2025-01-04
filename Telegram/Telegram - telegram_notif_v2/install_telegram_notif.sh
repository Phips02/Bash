#!/bin/bash

###############################################################################
# Script d'installation automatique des notifications Telegram
# Version 3.1
###############################################################################

# Fonction pour le logging avec horodatage et niveau
function log_message() {
    local level="$1"
    local message="$2"
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] [$level] $message"
}

# Fonction pour tracer les erreurs des commandes
function execute_command() {
    local cmd="$1"
    local description="$2"
    
    if ! eval "$cmd" 2>/tmp/cmd_error.log; then
        local error=$(cat /tmp/cmd_error.log)
        log_message "ERROR" "Échec de $description: $error"
        rm -f /tmp/cmd_error.log
        return 1
    fi
    rm -f /tmp/cmd_error.log
    return 0
}

# Vérification des droits root
if [[ $EUID -ne 0 ]]; then
    log_message "ERROR" "Ce script doit être exécuté en tant que root"
    exit 1
fi

# Fonction pour vérifier et installer les dépendances
function check_and_install_dependency() {
    local pkg_name="$1"
    local pkg_cmd="$2"
    log_message "INFO" "Vérification de $pkg_name..."
    
    if ! command -v "$pkg_cmd" &> /dev/null; then
        log_message "WARNING" "$pkg_cmd n'est pas installé. Installation en cours..."
        
        if ! execute_command "apt-get update" "mise à jour des dépôts"; then
            return 1
        fi
        
        if ! execute_command "apt-get install -y $pkg_name" "installation de $pkg_name"; then
            return 1
        fi
        
        log_message "SUCCESS" "$pkg_name installé avec succès"
    else
        log_message "INFO" "$pkg_cmd est déjà installé"
    fi
}

# Vérification des dépendances
for dep in "curl:curl" "jq:jq" "bash:bash"; do
    IFS=: read pkg cmd <<< "$dep"
    if ! check_and_install_dependency "$pkg" "$cmd"; then
        log_message "ERROR" "Échec de l'installation des dépendances"
        exit 1
    fi
done

# Création des répertoires nécessaires
BASE_DIR="/usr/local/bin/telegram/notif_connexion"
CONFIG_DIR="/etc/telegram/notif_connexion"
if ! execute_command "mkdir -p \"$BASE_DIR\" \"$CONFIG_DIR\"" "création des répertoires"; then
    exit 1
fi

# Création du groupe telegramnotif
if ! getent group telegramnotif > /dev/null; then
    if ! execute_command "groupadd telegramnotif" "création du groupe telegramnotif"; then
        exit 1
    fi
    log_message "SUCCESS" "Groupe telegramnotif créé"
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
                    if ! execute_command "cp /etc/hostname /etc/hostname.bak" "sauvegarde du hostname"; then
                        continue
                    fi
                    
                    if ! execute_command "echo \"$new_hostname\" > /etc/hostname" "modification du hostname"; then
                        continue
                    fi
                    
                    if ! execute_command "sed -i \"s/$current_hostname/$new_hostname/g\" /etc/hosts" "mise à jour des hosts"; then
                        continue
                    fi
                    
                    if ! execute_command "hostnamectl set-hostname \"$new_hostname\"" "application du nouveau hostname"; then
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
if ! execute_command "wget -q \"${REPO_URL}/telegram.sh\" -O \"${BASE_DIR}/telegram.sh\"" "téléchargement du script principal"; then
    exit 1
fi

if ! execute_command "chmod +x \"${BASE_DIR}/telegram.sh\"" "attribution des droits d'exécution"; then
    exit 1
fi

# Création du fichier de configuration
log_message "INFO" "Création du fichier de configuration..."
if ! execute_command "cat > \"$CONFIG_DIR/telegram.config\" << EOF
# Configuration Telegram
# Version 3.1
# Fichier : /etc/telegram/notif_connexion/telegram.config

TELEGRAM_BOT_TOKEN=\"${TELEGRAM_BOT_TOKEN}\"
TELEGRAM_CHAT_ID=\"${TELEGRAM_CHAT_ID}\"

# Chemins des dossiers et fichiers
BASE_DIR=\"${BASE_DIR}\"
CONFIG_DIR=\"${CONFIG_DIR}\"
SCRIPT_PATH=\"\$BASE_DIR/telegram.sh\"
CONFIG_PATH=\"\$CONFIG_DIR/telegram.config\"
EOF" "création du fichier de configuration"; then
    exit 1
fi

# Configuration des permissions
log_message "INFO" "Configuration des permissions..."
if ! execute_command "chmod 640 \"$CONFIG_DIR/telegram.config\"" "modification des permissions du fichier de configuration"; then
    exit 1
fi

if ! execute_command "chmod 750 \"$BASE_DIR/telegram.sh\"" "modification des permissions du script"; then
    exit 1
fi

if ! execute_command "chown root:telegramnotif \"$CONFIG_DIR/telegram.config\"" "modification du propriétaire du fichier de configuration"; then
    exit 1
fi

if ! execute_command "chown root:telegramnotif \"$BASE_DIR/telegram.sh\"" "modification du propriétaire du script"; then
    exit 1
fi

# Configuration système
log_message "INFO" "Configuration du système..."

# Ajout au bash.bashrc
if ! grep -q "\$SCRIPT_PATH" /etc/bash.bashrc; then
    if ! execute_command "echo '
# Notification Telegram pour connexions SSH et su
if [ -n \"\$PS1\" ] && [ \"\$TERM\" != \"unknown\" ]; then
    source $CONFIG_DIR/telegram.config
    \$SCRIPT_PATH &>/dev/null
fi' >> /etc/bash.bashrc" "configuration de bash.bashrc"; then
        exit 1
    fi
fi

# Configuration PAM
if ! grep -q "session.*telegram.sh" /etc/pam.d/su; then
    if ! execute_command "echo '# Notification Telegram pour su
session optional pam_exec.so seteuid source $CONFIG_DIR/telegram.config && \$SCRIPT_PATH' >> /etc/pam.d/su" "configuration de PAM"; then
        exit 1
    fi
fi

# Test de l'installation
log_message "INFO" "Test de l'installation..."
if ! execute_command "\"$BASE_DIR/telegram.sh\"" "test du script"; then
    log_message "ERROR" "Le test a échoué, vérifiez la configuration"
    exit 1
fi

log_message "SUCCESS" "Installation réussie!"
log_message "INFO" "Déconnectez-vous et reconnectez-vous pour activer les notifications"

# Auto-destruction du script
log_message "INFO" "Auto-destruction du script..."
if ! execute_command "rm -f \"$0\"" "suppression du script d'installation"; then
    log_message "WARNING" "Impossible de supprimer le script d'installation"
fi

exit 0



