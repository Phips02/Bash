#!/bin/bash

# Script de déploiement pour Phips Logger V2
# Version: 2025.03.16

set -e  # Arrêt du script en cas d'erreur

# Variables de base
GITHUB_REPO="https://raw.githubusercontent.com/Phips02/Bash/main/Phips_logger_V2"
INSTALL_DIR="/usr/local/bin/phips_logger"
CONFIG_DIR="/etc/phips_logger"
LOG_DIR="/var/log/phips_logger"
TEMP_DIR=$(mktemp -d)

# Codes couleurs pour les messages
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Fonction pour afficher les messages
log_message() {
    local level=$1
    local message=$2
    
    case "$level" in
        "INFO")     echo -e "${GREEN}[INFO]${NC} $message" ;;
        "WARNING")  echo -e "${YELLOW}[WARNING]${NC} $message" ;;
        "ERROR")    echo -e "${RED}[ERROR]${NC} $message" ;;
        "STEP")     echo -e "${BLUE}[STEP]${NC} $message" ;;
        *)          echo -e "$message" ;;
    esac
}

# Vérification des dépendances
check_dependencies() {
    log_message "STEP" "Vérification des dépendances..."
    
    local missing_deps=0
    for cmd in curl chmod mkdir grep; do
        if ! command -v $cmd &> /dev/null; then
            log_message "ERROR" "Commande '$cmd' non trouvée. Veuillez l'installer."
            missing_deps=1
        fi
    done
    
    if [ $missing_deps -eq 1 ]; then
        log_message "ERROR" "Dépendances manquantes. Installation annulée."
        exit 1
    fi
    
    log_message "INFO" "Toutes les dépendances sont installées."
}

# Vérification des permissions
check_permissions() {
    log_message "STEP" "Vérification des permissions..."
    
    if [ "$EUID" -ne 0 ]; then
        log_message "ERROR" "Ce script doit être exécuté avec les privilèges root (sudo)."
        exit 1
    fi
    
    log_message "INFO" "Exécution avec les bonnes permissions."
}

# Préparation des répertoires
prepare_directories() {
    log_message "STEP" "Création des répertoires nécessaires..."
    
    mkdir -p "$INSTALL_DIR"
    mkdir -p "$CONFIG_DIR"
    mkdir -p "$LOG_DIR"
    
    chmod 755 "$INSTALL_DIR"
    chmod 755 "$CONFIG_DIR"
    chmod 775 "$LOG_DIR"
    
    log_message "INFO" "Répertoires créés avec succès."
}

# Téléchargement des fichiers
download_files() {
    log_message "STEP" "Téléchargement des fichiers depuis GitHub..."
    
    # Liste des fichiers à télécharger avec leur destination
    declare -A files=(
        ["universal_logger.sh"]="$INSTALL_DIR/universal_logger.sh"
        ["logger_config.cfg"]="$CONFIG_DIR/logger_config.cfg"
    )
    
    for file in "${!files[@]}"; do
        local dest="${files[$file]}"
        local url="$GITHUB_REPO/$file"
        local temp_file="$TEMP_DIR/$file"
        
        log_message "INFO" "Téléchargement de $file..."
        if curl -s -o "$temp_file" "$url"; then
            # Vérifier si le fichier est vide ou contient une erreur HTML
            if [ ! -s "$temp_file" ] || grep -q "<html" "$temp_file"; then
                log_message "ERROR" "Échec du téléchargement de $file (fichier vide ou erreur 404)"
                exit 1
            fi
            
            # Copier le fichier vers sa destination finale
            cp "$temp_file" "$dest"
            log_message "INFO" "Fichier $file installé avec succès."
        else
            log_message "ERROR" "Échec du téléchargement de $file"
            exit 1
        fi
    done
    
    log_message "INFO" "Tous les fichiers ont été téléchargés avec succès."
}

# Configuration des permissions
configure_permissions() {
    log_message "STEP" "Configuration des permissions..."
    
    # Rendre le script exécutable
    chmod +x "$INSTALL_DIR/universal_logger.sh"
    
    # Protéger le fichier de configuration
    chmod 644 "$CONFIG_DIR/logger_config.cfg"
    
    log_message "INFO" "Permissions configurées avec succès."
}

# Test du logger
test_logger() {
    log_message "STEP" "Test du logger..."
    
    if "$INSTALL_DIR/universal_logger.sh" test; then
        log_message "INFO" "Test du logger réussi."
    else
        log_message "WARNING" "Le test du logger a échoué. Vérifiez les erreurs ci-dessus."
    fi
}

# Fonction de nettoyage
cleanup() {
    log_message "STEP" "Nettoyage des fichiers temporaires..."
    rm -rf "$TEMP_DIR"
    log_message "INFO" "Nettoyage terminé."
}

# Création du lien symbolique (optionnel)
create_symlink() {
    log_message "STEP" "Création du lien symbolique dans /usr/local/bin..."
    
    # Supprimer le lien existant s'il existe
    if [ -L "/usr/local/bin/phips-logger" ]; then
        rm "/usr/local/bin/phips-logger"
    fi
    
    # Créer le nouveau lien
    ln -s "$INSTALL_DIR/universal_logger.sh" "/usr/local/bin/phips-logger"
    
    log_message "INFO" "Lien symbolique créé avec succès."
}

# Installation du service systemd (optionnel)
install_service() {
    log_message "STEP" "Vérification de la présence de systemd..."
    
    if ! command -v systemctl &> /dev/null; then
        log_message "WARNING" "Systemd n'est pas disponible, impossible d'installer le service de rotation des logs."
        return
    fi
    
    log_message "INFO" "Création du service de rotation des logs..."
    
    # Créer le fichier de service
    cat > "/etc/systemd/system/phips-logger-rotate.service" << EOF
[Unit]
Description=Phips Logger - Rotation des logs
After=network.target

[Service]
Type=oneshot
ExecStart=/usr/local/bin/phips_logger/universal_logger.sh rotate 7
EOF

    # Créer le timer
    cat > "/etc/systemd/system/phips-logger-rotate.timer" << EOF
[Unit]
Description=Phips Logger - Timer de rotation quotidienne des logs

[Timer]
OnCalendar=daily
Persistent=true

[Install]
WantedBy=timers.target
EOF

    # Activer et démarrer le timer
    systemctl daemon-reload
    systemctl enable phips-logger-rotate.timer
    systemctl start phips-logger-rotate.timer
    
    log_message "INFO" "Service de rotation des logs installé et activé."
}

# Fonction principale
main() {
    log_message "STEP" "Démarrage de l'installation de Phips Logger V2..."
    
    # Gestion des erreurs et nettoyage
    trap cleanup EXIT
    
    # Exécution des étapes d'installation
    check_dependencies
    check_permissions
    prepare_directories
    download_files
    configure_permissions
    create_symlink
    
    # Étapes optionnelles
    install_service
    test_logger
    
    log_message "STEP" "Installation terminée avec succès!"
    log_message "INFO" "Le logger est maintenant installé dans $INSTALL_DIR"
    log_message "INFO" "Configuration dans $CONFIG_DIR"
    log_message "INFO" "Logs dans $LOG_DIR"
    log_message "INFO" "Utilisation: source $INSTALL_DIR/universal_logger.sh"
    log_message "INFO" "Ou directement: phips-logger [test|rotate|help]"
}

# Exécution du script
main