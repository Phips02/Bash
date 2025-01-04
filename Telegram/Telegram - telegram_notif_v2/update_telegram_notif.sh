#!/bin/bash

###############################################################################
# Script de mise à jour des notifications Telegram
# Version 3.3
###############################################################################

# Fonction pour le logging avec horodatage et niveau
function log_message() {
    local level="$1"
    local message="$2"
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] [$level] $message"
}

###############################################################################
# SECTION 0 : INITIALISATION DE LA CONFIGURATION
###############################################################################

# Création des répertoires si nécessaire
BASE_DIR="/usr/local/bin/telegram/notif_connexion"
CONFIG_DIR="/etc/telegram/notif_connexion"
mkdir -p "$BASE_DIR" "$CONFIG_DIR"

# Sauvegarde des tokens existants si le fichier existe
if [ -f "$CONFIG_DIR/telegram.config" ]; then
    source "$CONFIG_DIR/telegram.config"
    OLD_TOKEN="${TELEGRAM_BOT_TOKEN}"
    OLD_CHAT_ID="${TELEGRAM_CHAT_ID}"
fi

# Mise à jour du fichier de configuration avec les chemins
log_message "INFO" "Mise à jour de la configuration..."
cat <<EOF > "$CONFIG_DIR/telegram.config"
# Configuration Telegram
# Version 3.0
# A placer dans : /etc/telegram/notif_connexion/telegram.config

# Tokens et identifiants
TELEGRAM_BOT_TOKEN="${OLD_TOKEN:-}"
TELEGRAM_CHAT_ID="${OLD_CHAT_ID:-}"

# Chemins des dossiers et fichiers
BASE_DIR="/usr/local/bin/telegram/notif_connexion"
CONFIG_DIR="/etc/telegram/notif_connexion"
SCRIPT_PATH="\$BASE_DIR/telegram.sh"
CONFIG_PATH="\$CONFIG_DIR/telegram.config"
EOF

chmod 640 "$CONFIG_DIR/telegram.config"
chown root:telegramnotif "$CONFIG_DIR/telegram.config"
log_message "SUCCESS" "Configuration mise à jour"

# Création du groupe telegramnotif si nécessaire
if ! getent group telegramnotif > /dev/null; then
    groupadd telegramnotif
    log_message "INFO" "Groupe telegramnotif créé"
fi

###############################################################################
# SECTION 1 : VÉRIFICATIONS INITIALES
###############################################################################

# Vérification des droits root (nécessaire pour modifier les fichiers système)
if [[ $EUID -ne 0 ]]; then
    log_message "ERROR" "Ce script doit être exécuté en tant que root."
    exit 1
fi

# Fonction pour vérifier la présence des dépendances système requises
check_dependencies() {
    local dependencies=("curl" "jq" "wget")
    for dep in "${dependencies[@]}"; do
        if ! command -v "$dep" &> /dev/null; then
            log_message "ERROR" "Dépendance manquante : $dep"
            return 1
        fi
    done
    return 0
}

# Exécution de la vérification des dépendances
if ! check_dependencies; then
    log_message "ERROR" "Veuillez installer les dépendances manquantes"
    exit 1
fi

###############################################################################
# SECTION 2 : VÉRIFICATION DE LA CONFIGURATION
###############################################################################

# Fonction pour vérifier l'existence et la validité du fichier de configuration
check_config() {
    local config="/etc/telegram/notif_connexion/telegram.config"
    
    # Vérification de l'existence du fichier
    if [ ! -f "$config" ]; then
        log_message "ERROR" "Le fichier de configuration n'existe pas : $config"
        return 1
    fi

    # Vérification des droits de lecture
    if [ ! -r "$config" ]; then
        log_message "ERROR" "Le fichier de configuration n'est pas lisible : $config"
        return 1
    fi

    # Chargement et vérification des variables requises
    source "$config"
    local required_vars=("TELEGRAM_BOT_TOKEN" "TELEGRAM_CHAT_ID" "BASE_DIR" "CONFIG_DIR" "SCRIPT_PATH" "CONFIG_PATH")
    for var in "${required_vars[@]}"; do
        if [ -z "${!var}" ]; then
            log_message "ERROR" "Variable $var non définie dans $config"
            return 1
        fi
    done
    return 0
}

# Exécution de la vérification de la configuration
if ! check_config; then
    log_message "ERROR" "Configuration invalide. Installation requise."
    exit 1
fi

###############################################################################
# SECTION 3 : NETTOYAGE DES ANCIENNES VERSIONS
###############################################################################

# Fonction pour rechercher et gérer les anciennes versions des scripts
find_old_versions() {
    local search_dirs=("/etc" "/home" "/usr/local/bin" "/usr/local/bin/notif_connexion" "/usr/local/bin/telegram" "/etc/telegram")
    local found_files=()
    
    log_message "INFO" "Recherche d'anciennes versions..."
    
    # Recherche récursive des fichiers
    for dir in "${search_dirs[@]}"; do
        while IFS= read -r file; do
            if [[ "$file" != "$SCRIPT_PATH" && "$file" != "$CONFIG_PATH" ]]; then
                found_files+=("$file")
            fi
        done < <(find "$dir" -type f \( \
            -name "telegram*.sh" -o \
            -name "telegram*.config" -o \
            -name "telegram*.cfg" -o \
            -name "telegram*.conf" -o \
            -name "telegram*.ini" -o \
            -name "telegram*.credentials.sh" -o \
            -name "telegram*.functions.sh" -o \
            -name "deploy_telegram*.sh" -o \
            -name "telegram-notif*.sh" -o \
            -name "telegram-ssh*.sh" -o \
            -name "telegram_ssh*.sh" -o \
            -name "telegram_notif*.sh" -o \
            -name "telegram-bot*.sh" -o \
            -name "telegram_bot*.sh" \
        \) 2>/dev/null)
    done

    # Si aucun fichier trouvé, sortie
    if [ ${#found_files[@]} -eq 0 ]; then
        log_message "INFO" "Aucune ancienne version trouvée."
        return 0
    fi

    # Affichage du menu des options
    log_message "WARNING" "Anciennes versions trouvées :"
    echo "Options disponibles :"
    echo "  [o] Oui - supprimer ce fichier"
    echo "  [n] Non - conserver ce fichier"
    echo "  [t] Tout - supprimer tous les fichiers restants"
    echo "  [a] Annuler - arrêter et conserver les fichiers restants"
    echo "------------------------------------------------"

    # Traitement de chaque fichier trouvé
    for ((i=0; i<${#found_files[@]}; i++)); do
        local file_type=$(file -b "${found_files[$i]}")
        local file_date=$(stat -c %y "${found_files[$i]}" | cut -d. -f1)
        echo "[$i] ${found_files[$i]}"
        echo "    Type: $file_type"
        echo "    Date de modification: $file_date"
        
        # Boucle de demande de confirmation
        while true; do
            read -p "Supprimer ce fichier ? (o/n/t/a) : " choice
            case $choice in
                [oO])
                    if rm -f "${found_files[$i]}"; then
                        log_message "SUCCESS" "Suppression de : ${found_files[$i]}"
                    else
                        log_message "ERROR" "Échec de la suppression de : ${found_files[$i]}"
                    fi
                    break
                    ;;
                [nN])
                    log_message "INFO" "Conservation de : ${found_files[$i]}"
                    break
                    ;;
                [tT])
                    log_message "WARNING" "Suppression de tous les fichiers restants..."
                    for ((j=i; j<${#found_files[@]}; j++)); do
                        if rm -f "${found_files[$j]}"; then
                            log_message "SUCCESS" "Suppression de : ${found_files[$j]}"
                        else
                            log_message "ERROR" "Échec de la suppression de : ${found_files[$j]}"
                        fi
                    done
                    return 0
                    ;;
                [aA])
                    log_message "INFO" "Opération annulée. Conservation des fichiers restants."
                    return 0
                    ;;
                *)
                    echo "Option invalide. Utilisez o, n, t ou a."
                    ;;
            esac
        done
    done
}

# Exécution du nettoyage des anciennes versions
find_old_versions

###############################################################################
# SECTION 4 : MISE À JOUR DES FICHIERS
###############################################################################

# Vérification de la connexion internet
check_internet() {
    if ! ping -c 1 github.com &> /dev/null; then
        log_message "ERROR" "Pas de connexion internet"
        return 1
    fi
    return 0
}

if ! check_internet; then
    log_message "ERROR" "Une connexion internet est requise pour la mise à jour"
    exit 1
fi

# Création des sauvegardes
BACKUP_DIR="/etc/telegram/notif_connexion/backup"
BACKUP_DATE=$(date +%Y%m%d_%H%M%S)
mkdir -p "$BACKUP_DIR"

log_message "INFO" "Création d'une sauvegarde..."
cp "$CONFIG_PATH" "${BACKUP_DIR}/telegram.config.${BACKUP_DATE}"
cp "$SCRIPT_PATH" "${BACKUP_DIR}/telegram.sh.${BACKUP_DATE}"

# Téléchargement des nouveaux fichiers
REPO_URL="https://raw.githubusercontent.com/Phips02/Bash/main/Telegram/Telegram%20-%20telegram_notif_v2"
log_message "INFO" "Téléchargement des nouveaux fichiers..."

# Téléchargement et installation du script principal
if wget -q "${REPO_URL}/telegram.sh" -O "${SCRIPT_PATH}.tmp"; then
    # Vérification que le fichier n'est pas vide
    if [ -s "${SCRIPT_PATH}.tmp" ]; then
        mv "${SCRIPT_PATH}.tmp" "${SCRIPT_PATH}"
        chmod 750 "${SCRIPT_PATH}"
        chown root:telegramnotif "${SCRIPT_PATH}"
        log_message "SUCCESS" "Script principal mis à jour"
    else
        rm -f "${SCRIPT_PATH}.tmp"
        log_message "ERROR" "Le fichier téléchargé est vide"
        exit 1
    fi
else
    rm -f "${SCRIPT_PATH}.tmp"
    log_message "ERROR" "Échec du téléchargement du script"
    exit 1
fi

# Mise à jour du fichier de configuration
log_message "INFO" "Mise à jour du fichier de configuration..."
if wget -q "${REPO_URL}/telegram.config" -O "${CONFIG_PATH}.tmp"; then
    # Sauvegarde des variables existantes
    source "${CONFIG_PATH}"
    OLD_TOKEN="${TELEGRAM_BOT_TOKEN}"
    OLD_CHAT_ID="${TELEGRAM_CHAT_ID}"
    
    # Vérification du nouveau fichier
    if [ -s "${CONFIG_PATH}.tmp" ]; then
        # Mise à jour du fichier en conservant les tokens
        sed -i "s/TELEGRAM_BOT_TOKEN=.*/TELEGRAM_BOT_TOKEN=\"${OLD_TOKEN}\"/" "${CONFIG_PATH}.tmp"
        sed -i "s/TELEGRAM_CHAT_ID=.*/TELEGRAM_CHAT_ID=\"${OLD_CHAT_ID}\"/" "${CONFIG_PATH}.tmp"
        
        mv "${CONFIG_PATH}.tmp" "${CONFIG_PATH}"
        chmod 640 "${CONFIG_PATH}"
        chown root:telegramnotif "${CONFIG_PATH}"
        log_message "SUCCESS" "Fichier de configuration mis à jour"
    else
        rm -f "${CONFIG_PATH}.tmp"
        log_message "ERROR" "Le fichier de configuration téléchargé est vide"
        exit 1
    fi
else
    rm -f "${CONFIG_PATH}.tmp"
    log_message "ERROR" "Échec du téléchargement de la configuration"
    exit 1
fi

# Test du nouveau script
log_message "INFO" "Test du nouveau script..."
if ! "${SCRIPT_PATH}"; then
    log_message "ERROR" "Le test du nouveau script a échoué"
    # Restauration de la sauvegarde
    cp "${BACKUP_DIR}/telegram.sh.${BACKUP_DATE}" "${SCRIPT_PATH}"
    log_message "INFO" "Restauration de la sauvegarde effectuée"
    exit 1
fi

# Nettoyage du dossier tmp
cd /tmp
rm -f update_telegram_notif.sh*

###############################################################################
# SECTION 5 : VÉRIFICATIONS POST-INSTALLATION
###############################################################################

# Vérification de la configuration PAM
check_pam_config() {
    if ! grep -q "session.*telegram.sh" /etc/pam.d/su; then
        log_message "WARNING" "Configuration PAM manquante, réinstallation..."
        echo "session optional pam_exec.so seteuid source $CONFIG_DIR/telegram.config && \$SCRIPT_PATH" >> /etc/pam.d/su
    fi
}

check_pam_config

# Nettoyage des anciennes sauvegardes (garde les 10 dernières)
log_message "INFO" "Nettoyage des anciennes sauvegardes..."
cd "$BACKUP_DIR" && ls -t telegram.* | tail -n +11 | xargs -r rm

# Nettoyage final
cd /tmp
rm -f update_telegram_notif.sh* install_telegram_notif.sh*

# Message de fin
log_message "SUCCESS" "Mise à jour terminée avec succès!"
log_message "INFO" "Redémarrez votre session pour activer les changements"