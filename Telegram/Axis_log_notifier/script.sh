#!/bin/bash

# Phips
# Version : 2024.03.28 14:25

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

# Fonction pour convertir les KB en format lisible
format_memory() {
    local kb=$1
    if [ $kb -ge 1048576 ]; then # 1GB
        echo "$(awk "BEGIN {printf \"%.1f\", $kb/1048576}")GB"
    else
        echo "$(awk "BEGIN {printf \"%.1f\", $kb/1024}")MB"
    fi
}

# Fonction pour analyser les logs et extraire les problèmes
analyze_logs() {
    local systemlog="$1"
    local serverreport="$2"
    local message=""
    
    # En-tête avec date en premier
    message+=$"🕒 <b>Date:</b> $(date '+%Y-%m-%d %H:%M')\n"
    
    # Informations d'identification de la caméra
    local camera_model=$(grep "Product:" <<< "$serverreport" | sed 's/Product: AXIS \([^[:space:]]*\).*/\1/')
    message+=$"🎥 <b>Modèle:</b> $(escape_html "$camera_model")\n"
    
    # Identification de la caméra (simplifié)
    local camera_name=$(grep -m 1 "axis-" <<< "$systemlog" | awk '{print $2}')
    message+=$"📸 $(escape_html "$camera_name")\n"
    
    # Adresse IP (correction)
    local ip_address=$(grep -A4 "\[Network.eth0\]" <<< "$serverreport" | grep "IPAddress" | cut -d'"' -f2)
    message+=$"🌐 <b>IP:</b> $(escape_html "${ip_address:-N/A}")\n\n"
    
    # Spécifications techniques
    local architecture=$(grep "^Architecture[[:space:]]*=" <<< "$serverreport" | grep -o '"[^"]*"' | sed 's/"//g')
    local soc=$(grep "^Soc[[:space:]]*=" <<< "$serverreport" | grep -o '"[^"]*"' | sed 's/"//g')
    message+=$"💻 <b>Architecture:</b> $(escape_html "$architecture")\n"
    message+=$"🔲 <b>SoC:</b> $(escape_html "$soc")\n\n"
    
    # Applications installées
    message+=$"📱 <b>Applications:</b>\n"
    
    # Extraire la section des applications
    local apps_section=$(sed -n '/----- Uploaded applications -----/,/----- /p' <<< "$serverreport")
    
    # Parcourir chaque application
    while IFS= read -r line; do
        if [[ $line =~ ^Name:[[:space:]]*(.+)$ ]]; then
            app_name="${BASH_REMATCH[1]}"
        elif [[ $line =~ ^State:[[:space:]]*(.+)$ ]]; then
            app_state="${BASH_REMATCH[1]}"
            # Ajouter une icône en fonction de l'état
            if [[ "${app_state,,}" == "running" ]]; then
                message+=$"  ✅ ${app_name} (${app_state})\n"
            else
                message+=$"  ❌ ${app_name} (${app_state})\n"
            fi
        fi
    done <<< "$apps_section"
    
    message+=$"\n"
    
    # Températures
    message+=$"🌡️ <b>Températures:</b>\n"
    
    # Extraire la section des températures avec grep
    local temp_lines=$(grep "^S[0-9], Current:" <<< "$serverreport")
    
    # Parcourir chaque ligne de température
    while IFS= read -r line; do
        if [ -n "$line" ]; then
            local sensor=$(echo "$line" | cut -d',' -f1)
            local current_temp=$(echo "$line" | grep -o 'Current: [0-9.]\+C' | cut -d' ' -f2)
            local max_temp=$(echo "$line" | grep -o 'Percentiles:.*C' | awk '{print $NF}')
            
            # Extraire dynamiquement le nom du capteur depuis le serverreport
            local sensor_name=$(grep -A1 "TemperatureControl.Sensor.${sensor}]" <<< "$serverreport" | grep "Name" | cut -d'"' -f2)
            
            # Si aucun nom n'est trouvé, utiliser l'ID du capteur
            [ -z "$sensor_name" ] && sensor_name="$sensor"
            
            # Ajouter une icône en fonction de la température
            if [ -n "$current_temp" ]; then
                local temp_value=$(echo "$current_temp" | sed 's/C//' | awk '{print int($1)}')
                if [ "$temp_value" -gt 60 ]; then
                    message+=$"  🔴 ${sensor_name}: ${current_temp} (Max: ${max_temp})\n"
                elif [ "$temp_value" -gt 50 ]; then
                    message+=$"  🟡 ${sensor_name}: ${current_temp} (Max: ${max_temp})\n"
                else
                    message+=$"  🟢 ${sensor_name}: ${current_temp} (Max: ${max_temp})\n"
                fi
            fi
        fi
    done <<< "$temp_lines"
    
    message+=$"\n"
    
    # Statut du chauffage
    message+=$"🔥 <b>Chauffage:</b>\n"
    local heater_status=$(grep "^Heater H" <<< "$serverreport")
    if [ -n "$heater_status" ]; then
        if [[ "$heater_status" =~ "Running" ]]; then
            message+=$"  ♨️ ${heater_status##*Heater }\n"
        else
            message+=$"  ❄️ ${heater_status##*Heater }\n"
        fi
    fi
    message+=$"\n"
    
    # État du système
    message+=$"🔍 <b>État du Système:</b>\n"
    
    # Uptime
    local uptime=$(grep "Total Uptime:" <<< "$serverreport" | awk '{print $3, $4}')
    message+=$"• Uptime total: $(escape_html "$uptime")\n\n"
    
    # Reboots et Restarts
    local reboots=$(grep "Boot-up Counter:" <<< "$serverreport" | awk '{print $3}')
    local restarts=$(grep "Restart Counter:" <<< "$serverreport" | awk '{print $3}')
    message+=$"• Redémarrages:\n"
    message+=$"  - Hard: ${reboots}\n"
    message+=$"  - Soft: ${restarts}\n\n"
    
    # Mémoire
    local mem_total=$(grep "MemTotal:" <<< "$serverreport" | awk '{print $2}')
    local mem_available=$(grep "MemAvailable:" <<< "$serverreport" | awk '{print $2}')
    local mem_used=$((mem_total - mem_available))
    
    local total_readable=$(format_memory $mem_total)
    local used_readable=$(format_memory $mem_used)
    local available_readable=$(format_memory $mem_available)
    
    message+=$"• Mémoire RAM:\n"
    message+=$"  - Utilisée: ${used_readable}\n"
    message+=$"  - Libre: ${available_readable}\n"
    message+=$"  - Totale: ${total_readable}\n"
    

    
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