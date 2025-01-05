#!/bin/bash

# Charger les identifiants depuis le fichier de configuration
source /etc/telegram/notif_connexion/telegram.config

# Configuration de l'API Telegram
API="https://api.telegram.org/bot${TELEGRAM_BOT_TOKEN}"

# Fonction d'envoi de message Telegram
function telegram_text_send() {
    local TEXT="$1"
    if [[ -z "$TELEGRAM_CHAT_ID" || -z "$TEXT" ]]; then
        print_log "ERROR" "telegram.functions" "Chat ID ou texte manquant"
        return 1
    fi

    local response
    response=$(curl -s -d "chat_id=${TELEGRAM_CHAT_ID}&text=${TEXT}&parse_mode=markdown" "${API}/sendMessage" 2>/tmp/curl_error.log)
    local curl_status=$?

    if [ $curl_status -ne 0 ]; then
        local error=$(cat /tmp/curl_error.log)
        print_log "ERROR" "telegram.functions" "Échec de l'envoi du message: $error"
        rm -f /tmp/curl_error.log
        return 1
    fi

    if ! echo "$response" | jq -e '.ok' >/dev/null 2>&1; then
        print_log "ERROR" "telegram.functions" "Réponse API invalide: $response"
        return 1
    fi

    rm -f /tmp/curl_error.log
    return 0
}

# Fonction améliorée pour détecter l'IP source
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