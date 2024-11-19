#!/bin/bash

# Phips
# Version 2.2

# Ce script permet de déployer la stack de notification


# Vérification que le script est exécuté avec les droits root
if [[ $EUID -ne 0 ]]; then
   echo "Ce script doit être exécuté en tant que root." 
   exit 1
fi

# Fonction pour vérifier et installer les dépendances
function check_and_install_dependency() {
    local pkg_name="$1"
    local pkg_cmd="$2"
    local install_cmd="$3"
    
    if ! command -v "$pkg_cmd" &> /dev/null; then
        echo "$pkg_cmd n'est pas installé. Installation en cours..."
        apt-get update && apt-get install -y "$pkg_name"
    else
        echo "$pkg_cmd est déjà installé."
    fi
}

# Vérifier les dépendances
check_and_install_dependency "curl" "curl" "curl"
check_and_install_dependency "iproute2" "ip" "iproute2"
check_and_install_dependency "bash" "bash" "bash"

# Chemins des fichiers à créer
CONFIG_DIR="/etc/telegram/notif_connexion"
CONFIG_FILE="$CONFIG_DIR/telegram.config"
FUNCTIONS_FILE="/usr/local/bin/notif_connexion/telegram.functions.sh"
MAIN_SCRIPT="/usr/local/bin/notif_connexion/telegram.sh"
PROFILE_FILE="/etc/profile"
SCRIPT_PATH="/usr/local/bin/notif_connexion/telegram.sh"

# Création du répertoire de configuration si nécessaire
mkdir -p "$CONFIG_DIR"

# Demande du TOKEN et du CHAT ID Telegram
read -p "Entrez votre TOKEN Telegram : " TELEGRAM_BOT_TOKEN
read -p "Entrez votre Chat ID Telegram : " TELEGRAM_CHAT_ID

# Créer et sécuriser le fichier de configuration
echo "Création du fichier de configuration sécurisé..."
cat <<EOF > "$CONFIG_FILE"
TELEGRAM_BOT_TOKEN="${TELEGRAM_BOT_TOKEN}"
TELEGRAM_CHAT_ID="${TELEGRAM_CHAT_ID}"
EOF

# Assigner le fichier de configuration pour être lisible par tous
chmod 644 "$CONFIG_FILE"
echo "Fichier de configuration créé et accessible en lecture pour tous à : $CONFIG_FILE"

# Créer le fichier telegram.functions.sh
echo "Création du fichier de fonctions..."
cat <<'EOF' > "$FUNCTIONS_FILE"
#!/bin/bash

# Charger les identifiants depuis le fichier de configuration sécurisé
source /etc/telegram/notif_connexion/telegram.config

API="https://api.telegram.org/bot${TELEGRAM_BOT_TOKEN}"

function telegram_text_send() {
    local API="$API"
    local CHATID="$TELEGRAM_CHAT_ID"
    local PARSE_MODE="markdown"
    local TEXT="$1"
    local ENDPOINT="sendMessage"

    if [ -z "$CHATID" ] || [ -z "$TEXT" ]; then
	echo "---------------------------------------------"
        echo "Erreur : Le chat ID ou le texte est manquant."
	echo "---------------------------------------------"
        return 1
    fi

	curl -s -d "chat_id=${CHATID}&text=${TEXT}&parse_mode=${PARSE_MODE}" ${API}/${ENDPOINT} >/dev/null
}
EOF

chmod +x "$FUNCTIONS_FILE"
echo "Fichier de fonctions créé et accessible à : $FUNCTIONS_FILE"

# Créer le fichier telegram.sh
echo "Création du fichier principal..."
cat <<'EOF' > "$MAIN_SCRIPT"
#!/bin/bash

# Charger les identifiants et fonctions
source /etc/telegram/notif_connexion/telegram.config
source /usr/local/bin/notif_connexion/telegram.functions.sh

# Récupération des informations système
DATE=$(date "+%F %H:%M:%S")
IP_DEVICE=$(hostname -I | cut -d " " -f1)
MAC_ADDRESS=$(ip link show | grep ether | awk '{print $2}')
IP_LOCAL=$(echo $SSH_CLIENT |cut -d " " -f1)
#IP_LOCAL=$(hostname -I | awk '{print $1}')

# Récupération des informations publiques
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

# Construction du message
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

# Envoi du message Telegram
telegram_text_send "$TEXT"
EOF

chmod +x "$MAIN_SCRIPT"
echo "Fichier principal créé et accessible à : $MAIN_SCRIPT"

# Ajouter le script telegram.sh dans /etc/profile si ce n'est pas déjà fait
if ! grep -q "$SCRIPT_PATH" "$PROFILE_FILE"; then
    echo "$SCRIPT_PATH" >> "$PROFILE_FILE"
    echo "Le script $SCRIPT_PATH a été ajouté à /etc/profile pour exécution automatique à chaque connexion."
else
    echo "Le script $SCRIPT_PATH est déjà présent dans /etc/profile."
fi

# Envoi d'une notification pour aviser que le script a été déployé
SERVER_NAME=$(hostname)
IPINFO=$(curl -s ipinfo.io)
IP_PUBLIC=$(echo "$IPINFO" | jq -r '.ip')
IP_LOCAL=$(hostname -I | awk '{print $1}')

NOTIFY_TEXT="Le script de déploiement a été ajouté avec succès sur le serveur : %0A\
Nom du serveur : $SERVER_NAME %0A\
IP publique : $IP_PUBLIC %0A\
IP locale : $IP_LOCAL %0A"

# Ajouter un message spécial si l'IP publique correspond à 100.100.100.100
if [ "$IP_PUBLIC" == "100.100.100.100" ]; then
    NOTIFY_TEXT+="%0A\
L'IP publique correspond à l'adresse IP de Votre_IP_Perso."
fi

NOTIFY_TEXT+=" %0A\
Le script s'exécutera à chaque connexion."

echo "Envoi de la notification..."
source /usr/local/bin/notif_connexion/telegram.functions.sh  # Assurez-vous que les fonctions sont rechargées
if telegram_text_send "markdown" "$NOTIFY_TEXT"; then
    echo "Notification envoyée avec succès."
else
    echo "Erreur : La notification n'a pas pu être envoyée."
fi

# Supprimer le script deploy_telegram.sh
echo "Suppression du script deploy_telegram.sh..."
rm -- "$0"

echo "Déploiement terminé. Les scripts Telegram sont en place et le message de confirmation a été envoyé."
