#!/bin/bash

###############################################################################
# Script de notification Telegram pour les connexions SSH et su
###############################################################################

# Version du système
TELEGRAM_VERSION="4.6"

# Définition des chemins
BASE_DIR="/usr/local/bin/telegram/notif_connexion"
CONFIG_DIR="/etc/telegram/notif_connexion"

# Gestion des arguments
if [ "$1" = "--version" ]; then
    echo "Version $TELEGRAM_VERSION"
    exit 0
fi

# Fonction pour le logging avec horodatage, niveau et nom du script
function print_log() {
    local level="$1"
    local script="$2"
    local message="$3"
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] [$level] [$script] $message"
}

# Amélioration de la fonction source pour tracer les erreurs
function safe_source() {
    local config_file="$1"
    if [ ! -f "$config_file" ]; then
        print_log "ERROR" "telegram.sh" "Fichier de configuration introuvable: $config_file"
        return 1
    fi
    
    if ! source "$config_file" 2>/tmp/source_error.log; then
        local error=$(cat /tmp/source_error.log)
        print_log "ERROR" "telegram.sh" "Échec du chargement de $config_file: $error"
        rm -f /tmp/source_error.log
        return 1
    fi
    rm -f /tmp/source_error.log
    return 0
}

# Fonction pour vérifier la configuration
check_config() {
    local config="/etc/telegram/notif_connexion/telegram.config"
    
    print_log "INFO" "telegram.sh" "Vérification de la configuration..."
    if [ ! -f "$config" ]; then
        print_log "ERROR" "telegram.sh" "Le fichier de configuration n'existe pas : $config"
        return 1
    fi

    if [ ! -r "$config" ]; then
        print_log "ERROR" "telegram.sh" "Le fichier de configuration n'est pas lisible : $config"
        return 1
    fi

    if ! safe_source "$config"; then
        return 1
    fi

    local required_vars=("TELEGRAM_BOT_TOKEN" "TELEGRAM_CHAT_ID" "BASE_DIR" "CONFIG_DIR" "SCRIPT_PATH" "CONFIG_PATH")
    for var in "${required_vars[@]}"; do
        if [ -z "${!var}" ]; then
            print_log "ERROR" "telegram.sh" "Variable $var non définie dans $config"
            return 1
        fi
    done

    return 0
}

# Vérification de la configuration avant de continuer
if [ "$1" != "background" ]; then
    if ! check_config; then
        print_log "ERROR" "telegram.sh" "Échec de la vérification de la configuration"
        exit 1
    fi
fi

# Exécution en arrière-plan
if [ "$1" != "background" ]; then
    print_log "INFO" "telegram.sh" "Démarrage en arrière-plan..."
    exec $0 background > /dev/null 2>&1 &
    exit 0
fi

# Le reste du script continue ici en arrière-plan

# Vérification des dépendances
print_log "INFO" "telegram.sh" "Vérification des dépendances..."

for dep in jq curl; do
    if ! command -v "$dep" &> /dev/null; then
        print_log "ERROR" "telegram.sh" "Dépendance manquante : $dep"
        exit 1
    fi
done

# Configuration de l'API Telegram
API="https://api.telegram.org/bot${TELEGRAM_BOT_TOKEN}"

# Charger les fonctions communes
if [ ! -f "$BASE_DIR/telegram.functions.sh" ]; then
    print_log "ERROR" "telegram.sh" "Fichier de fonctions introuvable: $BASE_DIR/telegram.functions.sh"
    exit 1
fi
source "$BASE_DIR/telegram.functions.sh"

# Détection du type de connexion
get_connection_type() {
    local type
    if [ -n "$SSH_CONNECTION" ]; then
        type="SSH"
    elif [ -n "$PAM_TYPE" ]; then
        type="su/sudo"
    else
        type="Local"
    fi
    echo "$type"
}

# Récupération des informations système avec gestion d'erreurs
DATE=$(date "+%F %H:%M:%S")
IP_DEVICE=$(hostname -I 2>/dev/null | cut -d " " -f1) || IP_DEVICE="Indisponible"
MAC_ADDRESS=$(ip link show 2>/dev/null | grep ether | head -n1 | awk '{print $2}') || MAC_ADDRESS="Indisponible"
IP_LOCAL=$(get_source_ip 2>/dev/null) || IP_LOCAL="Indisponible"
CONNECTION_TYPE=$(get_connection_type 2>/dev/null) || CONNECTION_TYPE="Indisponible"

# Récupération des informations publiques avec gestion d'erreurs
IPINFO=$(curl -s ipinfo.io 2>/dev/null)
if [ $? -ne 0 ]; then
    IP_PUBLIC="Indisponible"
    COUNTRY="Indisponible"
else
    IP_PUBLIC=$(echo "$IPINFO" | jq -r '.ip // "Indisponible"')
    COUNTRY=$(echo "$IPINFO" | jq -r '.country // "Indisponible"')
fi

# Construction et envoi du message
TEXT="$DATE %0A\
------------------------------------------------ %0A\
Type de connexion : $CONNECTION_TYPE %0A\
Utilisateur : $USER %0A\
------------------------------------------------ %0A\
Appareil : $HOSTNAME %0A\
IP Locale : $IP_DEVICE %0A\
Adresse MAC : $MAC_ADDRESS %0A\
------------------------------------------------ %0A\
Connexion depuis : %0A\
IP Source : $IP_LOCAL %0A\
IP Publique : $IP_PUBLIC %0A\
Pays : $COUNTRY"

# Envoi du message
if ! telegram_text_send "$TEXT"; then
    print_log "ERROR" "telegram.sh" "Échec de l'envoi de la notification"
    exit 1
fi
print_log "SUCCESS" "telegram.sh" "Notification envoyée avec succès"
echo "" # Ajout d'une ligne vide pour un retour propre

exit 0