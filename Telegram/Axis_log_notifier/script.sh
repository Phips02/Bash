#!/bin/bash

# Phips
# Version : 2024.03.28 13:30

# Charger la configuration
CONFIG_FILE="/etc/${PROJECT_NAME:-AxisLogNotifier}/config.cfg"
[ ! -f "$CONFIG_FILE" ] && echo "Config non trouvée: $CONFIG_FILE" && exit 1

source "$CONFIG_FILE"
source "$LOGGER_PATH"

# Fonction pour échapper les caractères HTML
escape_html() {
    local text="$1"
    echo "$text" | sed 's/&/\&amp;/g; s/</\&lt;/g; s/>/\&gt;/g'
}

# Fonction pour simplifier les messages d'erreur
simplify_error() {
    local line="$1"
    # Extraire et formater la date et le message
    echo "$line" | sed -E 's/^([0-9]{4}-[0-9]{2}-[0-9]{2})T([0-9]{2}:[0-9]{2}):[0-9]{2}\.[0-9]+\+?[0-9:]*\s+axis-[a-z0-9]+\s+\[\s*[A-Z]+\s*\]\s+([^:]+:\s*.*)/\1 \2 \3/'
}

# Fonction pour lire le dernier timestamp
get_last_timestamp() {
    local timestamp_file="${TEMP_DIR}/last_check.txt"
    if [ -f "$timestamp_file" ]; then
        cat "$timestamp_file"
    else
        echo "1970-01-01T00:00:00"  # Date par défaut si le fichier n'existe pas
    fi
}

# Fonction pour sauvegarder le timestamp actuel
save_timestamp() {
    local timestamp_file="${TEMP_DIR}/last_check.txt"
    date -u "+%Y-%m-%dT%H:%M:%S" > "$timestamp_file"
}

# Fonction pour filtrer les nouvelles alertes
filter_new_alerts() {
    local log_content="$1"
    local last_check=$(get_last_timestamp)
    
    # Convertir le timestamp en secondes depuis l'epoch pour comparaison
    local last_check_seconds=$(date -d "$last_check" +%s)
    
    # Filtrer les lignes plus récentes que le dernier check
    while IFS= read -r line; do
        local line_date=$(echo "$line" | grep -oP '^[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}:[0-9]{2}')
        if [ -n "$line_date" ]; then
            local line_seconds=$(date -d "$line_date" +%s)
            if [ $line_seconds -gt $last_check_seconds ]; then
                echo "$line"
            fi
        fi
    done <<< "$log_content"
}

# Fonction pour analyser les logs et extraire les problèmes
analyze_logs() {
    local systemlog="$1"
    local serverreport="$2"
    local message=""
    
    # Filtrer les nouvelles alertes
    local new_systemlog=$(filter_new_alerts "$systemlog")
    
    # En-tête
    message+=$'🚨 <b>Alerte Caméra Axis</b>\n\n'
    
    # Identification de la caméra
    local camera_name=$(grep -m 1 "axis-" <<< "$systemlog" | awk '{print $2}')
    message+=$"📸 <b>Caméra:</b> $(escape_html "$camera_name")\n"
    message+=$"🕒 <b>Date:</b> $(date '+%Y-%m-%d %H:%M')\n\n"
    
    # Analyse des erreurs système par niveau
    message+=$'⚠️ <b>Alertes Système:</b>\n\n'
    
    # WARNING
    local warning_alerts=$(grep -E "\[ *WARNING *\]" <<< "$new_systemlog" | tail -n 5)
    if [ -n "$warning_alerts" ]; then
        message+=$"💡 <b>WARNING</b>\n"
        message+=$"Détail des 5 derniers warnings:\n"
        while IFS= read -r line; do
            local simplified=$(simplify_error "$line")
            message+=$"• $(escape_html "$simplified")\n\n"
        done <<< "$warning_alerts"
    else
        message+=$"💡 <b>WARNING</b> => ✅ Aucune alerte\n"
    fi
    
    # ERROR
    if grep -q "\[ *ERROR *\]" <<< "$new_systemlog"; then
        local error_count=$(grep -c "\[ *ERROR *\]" <<< "$new_systemlog")
        message+=$"🟠 <b>ERROR</b> => ⚠️ $error_count nouvelle(s) erreur(s)\n"
    else
        message+=$"🟠 <b>ERROR</b> => ✅ Aucune alerte\n"
    fi
    
    # CRITICAL
    if grep -q "\[ *CRITICAL *\]" <<< "$new_systemlog"; then
        local critical_count=$(grep -c "\[ *CRITICAL *\]" <<< "$new_systemlog")
        message+=$"🔴 <b>CRITICAL</b> => ⚠️ $critical_count nouvelle(s) erreur(s) critique(s)\n"
    else
        message+=$"🔴 <b>CRITICAL</b> => ✅ Aucune alerte\n"
    fi
    
    # FATAL
    if grep -q "\[ *FATAL *\]" <<< "$new_systemlog"; then
        local fatal_count=$(grep -c "\[ *FATAL *\]" <<< "$new_systemlog")
        message+=$"❌ <b>FATAL</b> => ⚠️ $fatal_count nouvelle(s) erreur(s) fatale(s)\n"
    else
        message+=$"❌ <b>FATAL</b> => ✅ Aucune alerte\n"
    fi
    message+=$'\n'
    
    # État du système (simplifié)
    message+=$'🔍 <b>État du Système:</b>\n'
    
    # Uptime
    local uptime=$(grep "Total Uptime:" <<< "$serverreport" | awk '{print $3, $4}')
    message+=$"• Uptime: $(escape_html "$uptime")\n\n"
    
    # Reboots et Restarts
    local reboots=$(grep "Boot-up Counter:" <<< "$serverreport" | awk '{print $3}')
    local restarts=$(grep "Restart Counter:" <<< "$serverreport" | awk '{print $3}')
    message+=$"• Boot: $(escape_html "$reboots") / Soft: $(escape_html "$restarts")\n"
    
    echo -e "$message"
}

# Programme principal
main() {
    print_log "INFO" "script" "Démarrage analyse des alertes Axis"
    
    # Récupérer les fichiers les plus récents
    local latest_systemlog=$(ls -t ${TEMP_DIR}/axis_systemlog_*.txt 2>/dev/null | head -n1)
    local latest_serverreport=$(ls -t ${TEMP_DIR}/axis_serverreport_*.txt 2>/dev/null | head -n1)
    
    # Vérifier que les fichiers existent
    if [ ! -f "$latest_systemlog" ] || [ ! -f "$latest_serverreport" ]; then
        print_log "ERROR" "script" "Fichiers de logs non trouvés"
        exit 1
    fi
    
    # Lire les données depuis les fichiers
    local system_log=$(cat "$latest_systemlog")
    local server_report=$(cat "$latest_serverreport")
    
    # Analyser et envoyer via Telegram
    if [ -n "${TELEGRAM_BOT_TOKEN}" ] && [ -n "${TELEGRAM_CHAT_ID}" ]; then
        local message=$(analyze_logs "$system_log" "$server_report")
        
        curl -s -X POST \
            "https://api.telegram.org/bot${TELEGRAM_BOT_TOKEN}/sendMessage" \
            --data-urlencode "chat_id=${TELEGRAM_CHAT_ID}" \
            --data-urlencode "text=${message}" \
            --data-urlencode "parse_mode=HTML"
        
        # Sauvegarder le timestamp après l'envoi réussi
        save_timestamp
        
        print_log "INFO" "script" "Rapport d'alertes envoyé via Telegram"
    else
        print_log "ERROR" "script" "Configuration Telegram manquante"
        exit 1
    fi
}

main