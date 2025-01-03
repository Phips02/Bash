#!/bin/bash

# Script de déploiement de la stack de notifications Telegram
# Version corrigée et fonctionnelle

#Phips
#Version : 2025.01.03 19:37

# Vérification que le script est exécuté en tant que root
if [[ $EUID -ne 0 ]]; then
    echo "Ce script doit être exécuté en tant que root."
    exit 1
fi

# Ajout d'une fonction de logging
function log_message() {
    local level="$1"
    local message="$2"
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] [$level] $message"
}

# Fonction améliorée pour vérifier et installer les dépendances
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

# Vérifier les dépendances requises
check_and_install_dependency "curl" "curl"
check_and_install_dependency "jq" "jq"
check_and_install_dependency "bash" "bash"

# Base path pour la configuration et les scripts
BASE_DIR="/usr/local/bin/telegram/notif_connexion"
CONFIG_DIR="/etc/telegram/notif_connexion"

# Fichiers de configuration et scripts
CONFIG_FILE="$CONFIG_DIR/telegram.config"
FUNCTIONS_FILE="$BASE_DIR/telegram.functions.sh"
SCRIPT_PATH="$BASE_DIR/telegram.sh"

# Création du répertoire de configuration si nécessaire
mkdir -p "$CONFIG_DIR"

# Validation du TOKEN Telegram (seulement si pas fourni en argument)
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

# Validation du Chat ID (seulement si pas fourni en argument)
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

# Affichage et modification potentielle du hostname
current_hostname=$(hostname)
log_message "INFO" "Hostname actuel du serveur : $current_hostname"

while true; do
    read -p "Voulez-vous modifier le hostname ? (o/n) : " change_hostname
    case $change_hostname in
        [oO]*)
            while true; do
                read -p "Entrez le nouveau hostname : " new_hostname
                if [[ $new_hostname =~ ^[a-zA-Z0-9-]+$ ]]; then
                    # Sauvegarde de l'ancien hostname
                    cp /etc/hostname /etc/hostname.bak
                    # Modification du hostname
                    echo "$new_hostname" > /etc/hostname
                    # Mise à jour du fichier hosts
                    sed -i "s/$current_hostname/$new_hostname/g" /etc/hosts
                    # Application immédiate du nouveau hostname
                    hostnamectl set-hostname "$new_hostname"
                    # Mettre à jour la variable HOSTNAME pour les messages
                    HOSTNAME=$new_hostname
                    export HOSTNAME
                    log_message "SUCCESS" "Hostname modifié avec succès : $new_hostname"
                    log_message "INFO" "Une sauvegarde de l'ancien hostname a été créée : /etc/hostname.bak"
                    break
                else
                    log_message "ERROR" "Format de hostname invalide. Utilisez uniquement des lettres, chiffres et tirets."
                fi
            done
            break
            ;;
        [nN]*)
            log_message "INFO" "Conservation du hostname actuel : $current_hostname"
            HOSTNAME=$current_hostname
            break
            ;;
        *)
            log_message "ERROR" "Répondez par 'o' pour oui ou 'n' pour non."
            ;;
    esac
done

# Attendre que le changement de hostname soit effectif
sleep 2

# Test de connexion à l'API Telegram
log_message "INFO" "Test de connexion à l'API Telegram..."
if ! curl -s "https://api.telegram.org/bot${TELEGRAM_BOT_TOKEN}/getMe" | grep -q "\"ok\":true"; then
    log_message "ERROR" "Impossible de se connecter à l'API Telegram. Vérifiez votre TOKEN."
    exit 1
fi

# Création et sécurisation du fichier de configuration
echo "Création du fichier de configuration sécurisé..."
cat <<EOF > "$CONFIG_FILE"
# Configuration Telegram
# Fichier : /etc/telegram/notif_connexion/telegram.config

TELEGRAM_BOT_TOKEN="${TELEGRAM_BOT_TOKEN}"
TELEGRAM_CHAT_ID="${TELEGRAM_CHAT_ID}"
EOF

# Permissions correctes dès le début
chmod 640 "$CONFIG_FILE"
chown root:telegramnotif "$CONFIG_FILE"

# Création du fichier telegram.functions.sh
echo "Création du fichier de fonctions..."
mkdir -p "$(dirname "$FUNCTIONS_FILE")"
cat <<'EOF' > "$FUNCTIONS_FILE"
#!/bin/bash

# Charger les identifiants depuis le fichier de configuration
source /etc/telegram/notif_connexion/telegram.config

API="https://api.telegram.org/bot${TELEGRAM_BOT_TOKEN}"

function telegram_text_send() {
    local TEXT="$1"
    if [[ -z "$TELEGRAM_CHAT_ID" || -z "$TEXT" ]]; then
        echo "Erreur : Chat ID ou texte manquant."
        return 1
    fi
    curl -s -d "chat_id=${TELEGRAM_CHAT_ID}&text=${TEXT}&parse_mode=markdown" "${API}/sendMessage" >/dev/null
}
EOF

chmod +x "$FUNCTIONS_FILE"
echo "Fichier de fonctions créé à : $FUNCTIONS_FILE"

# Chargement des fonctions
source "$FUNCTIONS_FILE"

# Création du script principal telegram.sh
echo "Création du fichier principal..."
cat <<'EOF' > "$SCRIPT_PATH"
#!/bin/bash

# Charger les identifiants et fonctions
source /etc/telegram/notif_connexion/telegram.config
source /usr/local/bin/telegram/notif_connexion/telegram.functions.sh

# Récupération des informations système
DATE=$(date "+%F %H:%M:%S")
IP_DEVICE=$(hostname -I | cut -d " " -f1)
MAC_ADDRESS=$(ip link show | grep ether | awk '{print $2}')

# Fonction améliorée pour détecter l'IP source et le type de connexion
get_source_ip() {
    # Pour les connexions SSH directes
    if [ -n "$SSH_CONNECTION" ]; then
        echo "$SSH_CONNECTION" | awk '{print $1}'
        return
    fi

    # Pour les sessions su/sudo, trouver la session SSH parente
    local parent_ssh_ip=""
    
    # Vérifier si on est dans une session su
    if [ -z "$SSH_CONNECTION" ] && [ "$TERM" != "unknown" ]; then
        # Obtenir le PID du processus parent
        local ppid=$PPID
        while [ "$ppid" -ne 1 ]; do
            # Vérifier si le processus parent est une session SSH
            local parent_cmd=$(ps -o cmd= -p $ppid)
            if [[ "$parent_cmd" == *"sshd"* ]]; then
                parent_ssh_ip=$(ss -tnp | grep "$ppid" | awk '{print $3}' | cut -d':' -f1)
                break
            fi
            # Remonter au processus parent suivant
            ppid=$(ps -o ppid= -p $ppid)
        done
    fi

    if [ -n "$parent_ssh_ip" ]; then
        echo "$parent_ssh_ip"
    else
        echo "Indisponible"
    fi
}

# Récupération de l'IP source
IP_LOCAL=$(get_source_ip)

# Récupération des informations publiques
IPINFO=$(curl -s ipinfo.io)
IP_PUBLIC=$(echo "$IPINFO" | jq -r '.ip')
COUNTRY=$(echo "$IPINFO" | jq -r '.country')

# Validation des informations récupérées
if [ -z "$IP_PUBLIC" ]; then
    IP_PUBLIC="Indisponible"
fi

# Construction du message de connexion
TEXT="$DATE %0A\
Connection from : %0A\
Local IP : $IP_LOCAL %0A\
Public IP : $IP_PUBLIC %0A\
Country : $COUNTRY %0A\
------------------------------------------------ %0A\
Device : $HOSTNAME %0A\
IP : $IP_DEVICE %0A\
MAC address : $MAC_ADDRESS %0A\
User : $USER"

# Envoi du message de connexion
telegram_text_send "$TEXT"
EOF

chmod +x "$SCRIPT_PATH"
echo "Fichier principal créé à : $SCRIPT_PATH"

# Sécurisation renforcée des fichiers
log_message "INFO" "Application des permissions..."
chown root:telegramnotif "$CONFIG_FILE"
chmod 640 "$CONFIG_FILE"
chown root:telegramnotif "$FUNCTIONS_FILE" "$SCRIPT_PATH"
chmod 750 "$FUNCTIONS_FILE" "$SCRIPT_PATH"

# Ajouter le script dans /etc/bash.bashrc
if ! grep -q "$BASE_DIR/telegram.sh" /etc/bash.bashrc; then
    log_message "INFO" "Ajout du script dans /etc/bash.bashrc..."
    cat >> /etc/bash.bashrc <<EOL

# Notification Telegram pour connexions SSH et su
if [ -n "\$PS1" ] && [ "\$TERM" != "unknown" ]; then
    $BASE_DIR/telegram.sh
fi
EOL
    log_message "SUCCESS" "Script ajouté à /etc/bash.bashrc"
fi

# Suppression du script de déploiement
rm -- "$0"

# Message de confirmation après la suppression du script
DATE=$(date "+%F %H:%M:%S")
IP_DEVICE=$(hostname -I | cut -d " " -f1)
MAC_ADDRESS=$(ip link show | grep ether | awk '{print $2}')
IP_LOCAL=$(echo $SSH_CLIENT | cut -d " " -f1)
IPINFO=$(curl -s ipinfo.io)
IP_PUBLIC=$(echo "$IPINFO" | jq -r '.ip')
COUNTRY=$(echo "$IPINFO" | jq -r '.country')

# Validation des informations récupérées
if [ -z "$IP_PUBLIC" ]; then
    IP_PUBLIC="Indisponible"
fi

# Validation de l'IP locale
if [ -z "$IP_LOCAL" ]; then
    IP_LOCAL="Indisponible"
fi

# Construction du message de confirmation du déploiement
DEPLOYMENT_TEXT="*Le script de déploiement a été exécuté avec succès sur :* %0A\
*Serveur :* $HOSTNAME %0A\
*IP publique :* $IP_PUBLIC %0A\
*IP locale :* $IP_LOCAL %0A\
*Pays :* $COUNTRY %0A\
*Date :* $DATE"

# Envoi du message de confirmation
telegram_text_send "$DEPLOYMENT_TEXT"

echo "Déploiement terminé. Le script de déploiement a été supprimé."

# Création du groupe telegramnotif si non existant
if ! getent group telegramnotif > /dev/null; then
    groupadd telegramnotif
    log_message "INFO" "Groupe telegramnotif créé"
fi

# Uniformiser les permissions
chmod 640 "$CONFIG_FILE"  # Une seule fois
# Ajouter le script à /etc/bash.bashrc pour les connexions su
if ! grep -q "$BASE_DIR/telegram.sh" /etc/bash.bashrc; then
    echo "# Notification Telegram pour connexions su" >> /etc/bash.bashrc
    echo "if [ -n \"\$PS1\" ]; then" >> /etc/bash.bashrc
    echo "    $BASE_DIR/telegram.sh" >> /etc/bash.bashrc
    echo "fi" >> /etc/bash.bashrc
    log_message "INFO" "Script ajouté à /etc/bash.bashrc"
fi

