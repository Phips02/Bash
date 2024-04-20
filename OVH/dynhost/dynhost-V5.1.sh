#!/bin/bash
#V5.1

# Pour le premier lancement du script ajouter la Cible 0.0.0.0 dans DynHost sur OVH




# Nom du client
CLIENT_NAME="Nom du client"

# Récupération dynamique du chemin de l'utilisateur
USER_PATH="/home/$USER"

# Chemin vers le fichier OVH
OVH_FILE_PATH="$USER_PATH/OVH/dynhost.credentials.sh"

# Fonction pour vérifier si les permissions du fichier OVH ont été modifiées
function check_permissions_changed() {
    local file="$1"
    # Vérifie si les permissions sont différentes de celles par défaut (600)
    [[ "$(stat -c %a "$file")" != "600" ]]
}

# Vérification si les permissions du fichier OVH ont déjà été modifiées
if check_permissions_changed "$OVH_FILE_PATH"; then
    echo "Les permissions du fichier OVH ont déjà été modifiées."
else
    # Changer les permissions du fichier pour qu'il soit accessible uniquement par l'utilisateur
    chmod 600 "$OVH_FILE_PATH"

    # Changer le propriétaire du fichier pour qu'il soit associé à l'utilisateur exécutant le script
    chown "$USER" "$OVH_FILE_PATH"
fi

# Récupération des tâches cron existantes
EXISTING_CRON=$(crontab -l 2>/dev/null)


# Ajout de l'entrée cron si elle n'existe pas déjà
if ! echo "$EXISTING_CRON" | grep -qF "*/5 * * * * $HOME/OVH/dynhost.sh"; then
    # Ajout de la nouvelle tâche cron
    NEW_CRON="*/5 * * * * $HOME/OVH/dynhost.sh"
    # Concaténation de la tâche existante avec la nouvelle tâche
    UPDATED_CRON=$(echo "$EXISTING_CRON"; echo "$NEW_CRON")
    # Réinscription des tâches cron mises à jour
    echo "$UPDATED_CRON" | crontab -
fi

# Validation des entrées utilisateur
if [ ! -f "$OVH_FILE_PATH" ]; then
    echo "Le fichier $OVH_FILE_PATH est introuvable."
    log_message "Le fichier $OVH_FILE_PATH est introuvable." "true"
    echo "-------------------------------------------------------" >> "$log"
    exit 1
fi

# Chargement sécurisé des informations d'identification OVH
source "$OVH_FILE_PATH" || { echo "Impossible de charger le fichier $OVH_FILE_PATH"; log_message "Impossible de charger le fichier $OVH_FILE_PATH" "true"; echo "-------------------------------------------------------" >> "$log"; exit 1; }

# Récupération de l'adresse IP actuelle
MY_IP=$(curl -s ipinfo.io/ip)
if [ -z "$MY_IP" ]; then
    echo "Impossible de récupérer l'adresse IP actuelle."
    log_message "Impossible de récupérer l'adresse IP actuelle." "true"
    echo "-------------------------------------------------------" >> "$log"
    exit 1
fi

# Initialisation du fichier de log
log="$USER_PATH/OVH/dynhost.log"
echo "-------------------------------------------------------" >> "$log"
echo "$(date '+%D %T') - Script démarré" >> "$log"

# Fonction pour enregistrer les messages dans le fichier de log et envoyer une notification Telegram
function log_message() {
    local message="$1"
    local is_error="$2"
    
    # Log dans le fichier
    local log_message="$(date '+%D %T') - $message"
    echo "$log_message" >> "$log"
    
    # Envoi de la notification Telegram en cas d'erreur
    if [ "$is_error" = "true" ]; then
        local text="Erreur : $message"
        send_telegram_message "$text"
    fi
}

# Fonction pour envoyer un message Telegram
function send_telegram_message() {
    local message="$1"
    local formatted_message=$(echo -e "$message" | sed 's/ /%20/g')
    local telegram_url="https://api.telegram.org/bot${TELEGRAM_BOT_TOKEN}/sendMessage"
    local response=$(curl -s -d "chat_id=${TELEGRAM_CHAT_ID}&text=$formatted_message&parse_mode=markdown" "$telegram_url")
    
    # Vérification de la réponse pour le débogage
    if [ "$response" ]; then
        echo "Réponse de Telegram : $response" >> "$log"
    else
        echo "Aucune réponse de Telegram." >> "$log"
    fi
}

# Comparaison des adresses IP
OLD_IP="0.0.0.0"
if [ -e "$USER_PATH/OVH/OLD_IP.txt" ]; then
    OLD_IP=$(< "$USER_PATH/OVH/OLD_IP.txt")
    log_message "Fichier OLD_IP.txt trouvé. Adresse IP précédente : $OLD_IP" "false"
fi

# Comparaison des adresses IP
if [ "$MY_IP" = "$OLD_IP" ]; then
    log_message "L'adresse IP n'a pas changé : $MY_IP" "false"
else
    log_message "L'adresse IP a changé. Nouvelle adresse : $MY_IP" "false"
    
    # Mise à jour de l'adresse IP DynHost
    url="https://www.ovh.com/nic/update?system=dyndns&hostname=$OVH_HOSTNAME&myip=$MY_IP"
    response=$(curl -s --user "$OVH_USERNAME:$OVH_PASSWD" "$url")
    log_message "Réponse de la mise à jour DynHost : $response" "false"
    
    # Vérification de la réponse pour détecter les erreurs
    if [[ "$response" != good* ]]; then
        log_message "Erreur lors de la mise à jour DynHost : $response" "true"
        echo "-------------------------------------------------------" >> "$log"
        exit 1
    fi
    
    # Ne pas envoyer de notification Telegram si la réponse de OVH est "nochg"
    if [[ "$response" == nochg* ]]; then
        log_message "Aucune modification de l'adresse IP détectée. Pas de notification Telegram envoyée." "false"
    else
        # Envoi du message Telegram
        TEXT=$(printf "%s\n*%s*\nUpdate public IP address on OVH DynHost\nOLD IP : %s\nNEW IP : %s" \
            "$(date '+%F %H:%M:%S')" \
            "$CLIENT_NAME" \
            "$OLD_IP" \
            "$MY_IP")
        
        send_telegram_message "$TEXT"
        log_message "Message Telegram envoyé." "false"
    fi
    
    # Mise à jour de l'adresse IP dans le fichier OLD_IP.txt
    echo "$MY_IP" > "$USER_PATH/OVH/OLD_IP.txt" || log_message "Erreur lors de la mise à jour du fichier OLD_IP.txt" "true"
fi

log_message "Script terminé" "false"
echo "-------------------------------------------------------" >> "$log"
