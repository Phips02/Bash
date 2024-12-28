#!/bin/bash

# Phips
# Version : 2024.03.28 13:30

# Charger la configuration
source "/etc/AxisLogNotifier/config.cfg"

# Fonction de logging
log() {
    local level="$1"
    local component="$2"
    local message="$3"
    
    if [ -f "${LOGGER_PATH}" ]; then
        "${LOGGER_PATH}" "${level}" "${component}" "${message}"
    else
        echo "ERROR: Logger not found at ${LOGGER_PATH}"
        echo "${level} - ${component} - ${message}"
    fi
}

# Test de connexion à la caméra
test_camera_connection() {
    echo "🔍 Test de connexion à la caméra ${AXIS_CAMERA_IP}..."
    log "DEBUG" "fetch_axis_data" "Test de connexion à la caméra ${AXIS_CAMERA_IP}"
    
    local test_url="${AXIS_CAMERA_PROTOCOL}://${AXIS_CAMERA_IP}/axis-cgi/admin/systemlog.cgi"
    local curl_output
    local response_content
    
    echo "📡 Tentative de connexion à : ${test_url}"
    echo "👤 Utilisateur : ${AXIS_CAMERA_USER}"
    
    response_content=$(curl -s -k --digest \
        -u "${AXIS_CAMERA_USER}:${AXIS_CAMERA_PASS}" \
        --connect-timeout "${OPERATION_TIMEOUT}" \
        "${test_url}")
    
    if [[ "$response_content" == *"System log"* ]]; then
        local camera_name=$(echo "${response_content}" | grep -m 1 "axis-" | awk '{print $2}')
        echo "✅ Connexion réussie !"
        echo "📸 Nom de la caméra : ${camera_name}"
        echo "----------------------------------------"
        log "INFO" "fetch_axis_data" "Connexion réussie à la caméra ${camera_name}"
        return 0
    else
        echo "❌ Échec de la connexion"
        log "ERROR" "fetch_axis_data" "Échec de connexion à la caméra"
        return 1
    fi
}

# Fonction générique pour récupérer les données
fetch_data() {
    local type="$1"
    local url="$2"
    local timeout="$3"
    
    echo "📥 Récupération des ${type}..."
    log "DEBUG" "fetch_axis_data" "Tentative de récupération des ${type}"
    
    local output_file="${TEMP_DIR}/axis_${type}_$(date +%Y%m%d_%H%M%S).txt"
    local curl_output
    
    echo "📡 URL : ${url}"
    
    curl_output=$(curl -s -k --digest \
        -u "${AXIS_CAMERA_USER}:${AXIS_CAMERA_PASS}" \
        --connect-timeout "${timeout}" \
        "${url}" 2>&1)
    
    local curl_exit=$?
    
    if [ $curl_exit -eq 0 ] && [ -n "$curl_output" ]; then
        echo "✅ ${type} récupérés avec succès"
        echo "💾 Sauvegarde dans : ${output_file}"
        echo "${curl_output}" > "${output_file}"
        log "INFO" "fetch_axis_data" "${type} sauvegardés dans ${output_file}"
        echo "${output_file}"
        return 0
    else
        echo "❌ Échec de la récupération des ${type}"
        echo "🔍 Erreur curl : ${curl_output}"
        log "ERROR" "fetch_axis_data" "Échec de récupération des ${type}"
        return 1
    fi
}

# Fonctions spécifiques utilisant la fonction générique
get_system_logs() {
    fetch_data "systemlog" "${AXIS_CAMERA_PROTOCOL}://${AXIS_CAMERA_IP}/axis-cgi/admin/systemlog.cgi" "${AXIS_SYSTEMLOG_TIMEOUT}"
}

get_server_report() {
    fetch_data "serverreport" "${AXIS_CAMERA_PROTOCOL}://${AXIS_CAMERA_IP}/axis-cgi/serverreport.cgi?mode=text" "${AXIS_SERVERREPORT_TIMEOUT}"
}

get_access_logs() {
    fetch_data "accesslog" "${AXIS_CAMERA_PROTOCOL}://${AXIS_CAMERA_IP}/axis-cgi/admin/accesslog.cgi" "${OPERATION_TIMEOUT}"
}

# Fonction pour afficher les dernières lignes d'un fichier
show_last_lines() {
    local file="$1"
    local name="$2"
    
    if [ -f "$file" ]; then
        echo "📄 Dernières lignes de ${name} :"
        echo "----------------------------------------"
        tail -n 5 "$file"
        echo "----------------------------------------"
    else
        echo "❌ Fichier ${name} non trouvé : ${file}"
    fi
}

# Fonction principale
main() {
    log "INFO" "fetch_axis_data" "Démarrage du script"
    
    # Vérification des prérequis
    if [ -z "${AXIS_CAMERA_IP}" ] || [ -z "${AXIS_CAMERA_USER}" ] || [ -z "${AXIS_CAMERA_PASS}" ]; then
        log "ERROR" "fetch_axis_data" "Configuration incomplète de la caméra"
        exit 1
    fi
    
    # Création du répertoire temporaire si nécessaire
    if ! mkdir -p "${TEMP_DIR}"; then
        log "ERROR" "fetch_axis_data" "Impossible de créer le répertoire temporaire"
        exit 1
    fi
    
    # Test de connexion à la caméra
    if ! test_camera_connection; then
        log "ERROR" "fetch_axis_data" "Test de connexion échoué"
        exit 1
    fi
    
    # Récupération des différents logs
    if ! get_system_logs; then
        log "ERROR" "fetch_axis_data" "Échec de la récupération des logs système"
        exit 1
    fi
    
    if ! get_server_report; then
        log "ERROR" "fetch_axis_data" "Échec de la récupération du rapport serveur"
        exit 1
    fi
    
    if ! get_access_logs; then
        log "ERROR" "fetch_axis_data" "Échec de la récupération des logs d'accès"
        exit 1
    fi
    
    # Afficher les dernières lignes de chaque fichier
    echo -e "\n📋 Vérification des fichiers générés :"
    
    # Trouver les fichiers les plus récents
    local latest_systemlog=$(ls -t ${TEMP_DIR}/axis_systemlog_*.txt 2>/dev/null | head -n1)
    local latest_serverreport=$(ls -t ${TEMP_DIR}/axis_serverreport_*.txt 2>/dev/null | head -n1)
    local latest_accesslog=$(ls -t ${TEMP_DIR}/axis_accesslog_*.txt 2>/dev/null | head -n1)
    
    show_last_lines "$latest_systemlog" "logs système"
    show_last_lines "$latest_serverreport" "rapport serveur"
    show_last_lines "$latest_accesslog" "logs d'accès"
    
    log "INFO" "fetch_axis_data" "Script terminé avec succès"
}

# Exécuter le script
main "$@" 