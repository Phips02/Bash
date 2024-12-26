#!/bin/bash

#A placer dans /usr/local/bin/ftp_video/telegram.functions.sh

#Phips
# Version : 2024.12.26 21:00

# Charger la configuration
CONFIG_FILE="/etc/telegram/ftp_video/ftp_config.cfg"

# Vérifier si le fichier de configuration existe
if [ ! -f "$CONFIG_FILE" ]; then
    echo "Fichier de configuration non trouvé: $CONFIG_FILE"
    exit 1
fi

# Charger la configuration
source "$CONFIG_FILE"

# Vérifier les chemins essentiels
for path_var in "BASE_DIR" "CONFIG_BASE_DIR" "LOG_DIR" "LOGGER_PATH"; do
    if [ -z "${!path_var}" ]; then
        echo "Erreur: $path_var n'est pas défini dans la configuration"
        exit 1
    fi
done

# Vérifier si le fichier logger existe
if [ ! -f "$LOGGER_PATH" ]; then
    echo "Logger non trouvé: $LOGGER_PATH"
    exit 1
fi

# Charger le logger
source "$LOGGER_PATH"

API="https://api.telegram.org/bot${TELEGRAM_BOT_TOKEN}"

# Vérification immédiate du logger
if ! declare -f print_log >/dev/null; then
    echo "ERREUR: Logger non chargé correctement"
    exit 1
fi

# Ajouter une vérification du token
if [ -z "$TELEGRAM_BOT_TOKEN" ]; then
    print_log "CRITICAL" "telegram.functions" "TELEGRAM_BOT_TOKEN non défini"
    exit 1
fi

# Fonction de validation complète de Telegram
function validate_telegram_token() {
    local response
    local retry_count=0
    local max_retries=3

    while [ $retry_count -lt $max_retries ]; do
        response=$(curl -s "${API}/getMe")
        if echo "$response" | grep -q '"ok":true'; then
            print_log "INFO" "telegram.functions" "Validation du token Telegram réussie"
            return 0
        fi
        
        ((retry_count++))
        print_log "WARNING" "telegram.functions" "Échec de la validation du token (tentative $retry_count/$max_retries)"
        sleep 2
    done

    print_log "ERROR" "telegram.functions" "Échec de la validation du token après $max_retries tentatives"
    return 1
}

# Fonction de test d'envoi de message
function test_telegram_send() {
    local test_message="Test de connexion Telegram"
    
    print_log "INFO" "telegram.functions" "Test d'envoi de message Telegram"
    if telegram_text_send "HTML" "$test_message"; then
        print_log "INFO" "telegram.functions" "Test d'envoi réussi"
        return 0
    else
        print_log "ERROR" "telegram.functions" "Échec du test d'envoi"
        return 1
    fi
}

# Fonction pour échapper les caractères spéciaux HTML
escape_html() {
    local text="$1"
    text="${text//&/&amp;}"
    text="${text//</&lt;}"
    text="${text//>/&gt;}"
    echo "$text"
}

# Fonction pour formater le texte en HTML
format_html() {
    local text="$1"
    local format="$2"
    
    case "$format" in
        "bold")      echo "<b>$(escape_html "$text")</b>" ;;
        "italic")    echo "<i>$(escape_html "$text")</i>" ;;
        "underline") echo "<u>$(escape_html "$text")</u>" ;;
        "code")      echo "<code>$(escape_html "$text")</code>" ;;
        "pre")       echo "<pre>$(escape_html "$text")</pre>" ;;
        *)           echo "$(escape_html "$text")" ;;
    esac
}

# Fonction pour envoyer un message via Telegram
function telegram_text_send() {
    local PARSE_MODE="$1"
    local TEXT="$2"
    local CHATID="${3:-$TELEGRAM_CHAT_ID}"  # Utilise le chat ID fourni ou celui par défaut
    local ENDPOINT="sendMessage"
    local RESPONSE

    # Vérification des paramètres
    if [ -z "$PARSE_MODE" ]; then
        PARSE_MODE="HTML"  # Mode par défaut
    fi

    if [ -z "$CHATID" ] || [ -z "$TEXT" ]; then
        print_log "ERROR" "telegram.functions" "Le chat ID ou le texte est manquant"
        return 1
    fi

    # Échapper le texte si mode HTML
    if [ "$PARSE_MODE" = "HTML" ]; then
        TEXT="$(escape_html "$TEXT")"
    fi

    # Ajout de la gestion des erreurs pour curl
    RESPONSE=$(curl -s -d "chat_id=${CHATID}&text=${TEXT}&parse_mode=${PARSE_MODE}" "${API}/${ENDPOINT}")
    if ! echo "$RESPONSE" | grep -q '"ok":true'; then
        print_log "ERROR" "telegram.functions" "Erreur lors de l'envoi du message: $RESPONSE"
        return 1
    fi
    
    print_log "INFO" "telegram.functions" "Message envoyé avec succès"
    return 0
}

# Fonction pour envoyer une vidéo via Telegram
function telegram_video_send() {
    local VIDEO_FILE="$1"
    local CAPTION="$2"
    local CHATID="${3:-$TELEGRAM_CHAT_ID}"
    local ENDPOINT="sendVideo"
    local RESPONSE

    if [ ! -f "$VIDEO_FILE" ]; then
        print_log "ERROR" "telegram.functions" "Fichier vidéo non trouvé: $VIDEO_FILE"
        return 1
    fi

    if [ -z "$CHATID" ]; then
        print_log "ERROR" "telegram.functions" "Chat ID manquant"
        return 1
    fi

    # Échapper la légende pour HTML
    CAPTION="$(escape_html "$CAPTION")"

    RESPONSE=$(curl -s -F "chat_id=${CHATID}" \
                      -F "video=@${VIDEO_FILE}" \
                      -F "caption=${CAPTION}" \
                      -F "parse_mode=HTML" \
                      "${API}/${ENDPOINT}")

    if ! echo "$RESPONSE" | grep -q '"ok":true'; then
        print_log "ERROR" "telegram.functions" "Erreur lors de l'envoi de la vidéo: $RESPONSE"
        return 1
    fi

    print_log "INFO" "telegram.functions" "Vidéo envoyée avec succès vers chat ID: ${CHATID}"
    return 0
}