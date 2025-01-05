#!/bin/bash

###############################################################################
# Script d'installation automatique des notifications Telegram
###############################################################################

# Version du système
TELEGRAM_VERSION="3.51"

# Définition des chemins
BASE_DIR="/usr/local/bin/telegram/notif_connexion"
CONFIG_DIR="/etc/telegram/notif_connexion"

# Fonction pour le logging avec horodatage, niveau et nom du script
function print_log() {
    local level="$1"
    local script="$2"
    local message="$3"
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] [$level] [$script] $message"
}

print_log "INFO" "install.sh" "Exécution du script d'installation version $TELEGRAM_VERSION"

# Vérification des droits root
if [[ $EUID -ne 0 ]]; then
    print_log "ERROR" "install.sh" "Ce script doit être exécuté en tant que root"
    exit 1
fi

# Vérification et installation des dépendances
for pkg in curl jq bash adduser; do
    print_log "INFO" "install.sh" "Vérification de $pkg..."
    if ! command -v "$pkg" &> /dev/null; then
        print_log "WARNING" "install.sh" "$pkg n'est pas installé. Installation en cours..."
        apt-get update && apt-get install -y "$pkg"
        if [ $? -ne 0 ]; then
            print_log "ERROR" "install.sh" "Échec de l'installation de $pkg"
            exit 1
        fi
        print_log "SUCCESS" "install.sh" "$pkg installé avec succès"
    fi
done

# Création des répertoires nécessaires
mkdir -p "$BASE_DIR" "$CONFIG_DIR"
if [ $? -ne 0 ]; then
    print_log "ERROR" "install.sh" "Échec de la création des répertoires"
    exit 1
fi

# Création du groupe telegramnotif
if ! getent group telegramnotif > /dev/null; then
    groupadd telegramnotif
    if [ $? -ne 0 ]; then
        print_log "ERROR" "install.sh" "Échec de la création du groupe"
        exit 1
    fi
    print_log "SUCCESS" "install.sh" "Groupe telegramnotif créé"
fi

# Ajout de l'utilisateur au groupe si nécessaire
if ! groups "$USER" | grep -q "telegramnotif"; then
    usermod -a -G telegramnotif "$USER"
    if [ $? -ne 0 ]; then
        print_log "WARNING" "install.sh" "Impossible d'ajouter l'utilisateur au groupe telegramnotif"
    else
        print_log "SUCCESS" "install.sh" "Utilisateur ajouté au groupe telegramnotif"
    fi
fi

# Validation du TOKEN Telegram
if [ -z "$TELEGRAM_BOT_TOKEN" ]; then
    while true; do
        read -p "Entrez votre TOKEN Telegram : " TELEGRAM_BOT_TOKEN
        if [[ $TELEGRAM_BOT_TOKEN =~ ^[0-9]+:[a-zA-Z0-9_-]+$ ]]; then
            break
        else
            print_log "ERROR" "install.sh" "Format de TOKEN invalide. Format attendu: 123456789:ABCdefGHIjklMNOpqrsTUVwxyz"
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
            print_log "ERROR" "install.sh" "Format de Chat ID invalide. Doit être un nombre"
        fi
    done
fi

# Gestion du hostname
current_hostname=$(hostname)
print_log "INFO" "install.sh" "Hostname actuel du serveur : $current_hostname"

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
                        print_log "ERROR" "install.sh" "Échec de la sauvegarde du hostname"
                        continue
                    fi
                    
                    # Modification du hostname
                    echo "$new_hostname" > /etc/hostname
                    if [ $? -ne 0 ]; then
                        print_log "ERROR" "install.sh" "Échec de la modification du hostname"
                        continue
                    fi
                    
                    # Mise à jour des hosts
                    sed -i "s/$current_hostname/$new_hostname/g" /etc/hosts
                    if [ $? -ne 0 ]; then
                        print_log "ERROR" "install.sh" "Échec de la mise à jour des hosts"
                        continue
                    fi
                    
                    # Application du nouveau hostname
                    hostnamectl set-hostname "$new_hostname"
                    if [ $? -ne 0 ]; then
                        print_log "ERROR" "install.sh" "Échec de l'application du nouveau hostname"
                        continue
                    fi
                    
                    HOSTNAME=$new_hostname
                    export HOSTNAME
                    print_log "SUCCESS" "install.sh" "Hostname modifié avec succès : $new_hostname"
                    break
                else
                    print_log "ERROR" "install.sh" "Format de hostname invalide. Utilisez uniquement des lettres, chiffres et tirets"
                fi
            done
            break
            ;;
        [nN]*)
            HOSTNAME=$current_hostname
            break
            ;;
        *)
            print_log "ERROR" "install.sh" "Répondez par 'o' pour oui ou 'n' pour non"
            ;;
    esac
done

# Téléchargement et installation des fichiers
REPO_URL="https://raw.githubusercontent.com/Phips02/Bash/main/Telegram/Telegram%20-%20telegram_notif_v2"

print_log "INFO" "install.sh" "Téléchargement de telegram.sh..."
wget -q "${REPO_URL}/telegram.sh" -O "${BASE_DIR}/telegram.sh"
if [ $? -ne 0 ]; then
    print_log "ERROR" "install.sh" "Échec du téléchargement du script"
    exit 1
fi

chmod +x "${BASE_DIR}/telegram.sh"
if [ $? -ne 0 ]; then
    print_log "ERROR" "install.sh" "Échec de l'attribution des droits d'exécution"
    exit 1
fi

# Création du fichier de configuration
print_log "INFO" "install.sh" "Création du fichier de configuration..."
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
    print_log "ERROR" "install.sh" "Échec de la création du fichier de configuration"
    exit 1
fi

# Configuration des permissions
print_log "INFO" "install.sh" "Configuration des permissions..."

# Permissions des répertoires
chmod 755 "$BASE_DIR"           # rwxr-xr-x - Accès pour tous
chmod 755 "$CONFIG_DIR"         # rwxr-xr-x - Accès pour tous
chmod 644 "$CONFIG_PATH"        # rw-r--r-- - Lecture pour tous
chmod 755 "$SCRIPT_PATH"        # rwxr-xr-x - Exécution pour tous

# Propriétaire et groupe
chown -R root:root "$BASE_DIR" "$CONFIG_DIR"

# Configuration bash.bashrc
echo '
# Notification Telegram pour connexions SSH et su
if [ -n "$SSH_CONNECTION" ]; then
    '"$SCRIPT_PATH"' &>/dev/null || true
fi' >> /etc/bash.bashrc

# Configuration PAM
PAM_LINE="session optional pam_exec.so seteuid $SCRIPT_PATH"

# Test de l'installation
print_log "INFO" "install.sh" "Test de l'installation..."
"$BASE_DIR/telegram.sh" &
test_pid=$!

# Attendre la fin du test
wait $test_pid

# Auto-destruction du script
print_log "INFO" "install.sh" "Auto-destruction du script..."
rm -f "$0"
if [ $? -ne 0 ]; then
    print_log "WARNING" "install.sh" "Impossible de supprimer le script d'installation"
fi

# Sécurisation des fichiers sensibles
chattr +i "$CONFIG_DIR/telegram.config"  # Empêcher la modification

# Configuration logrotate
cat > /etc/logrotate.d/telegram_notif << EOF
/var/log/telegram_notif/*.log {
    weekly
    rotate 4
    compress
    missingok
    notifempty
}
EOF

# Message final
print_log "SUCCESS" "install.sh" "Installation terminée avec succès!"
echo "" # Ajout d'une ligne vide pour un retour propre

exit 0
