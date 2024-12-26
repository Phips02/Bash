#!/bin/bash

#A placer dans /usr/local/bin/ftp_video/update.sh

#Phips
#Version : 2024.12.26 20:40

# Charger la configuration
CONFIG_FILE="/etc/telegram/ftp_video/ftp_config.cfg"

# Vérifier si le fichier de configuration existe
if [ ! -f "$CONFIG_FILE" ]; then
    echo "Fichier de configuration non trouvé: $CONFIG_FILE"
    exit 1
fi

# Charger la configuration
source "$CONFIG_FILE"

# Charger le logger
source "$LOGGER_PATH"

print_log "info" "update" "Démarrage de la mise à jour depuis GitHub"

# Créer un dossier temporaire pour le clone
TEMP_DIR="/tmp/Bash_update_$$"
print_log "info" "update" "Création du dossier temporaire: $TEMP_DIR"

# Définir le dossier de backup avec date et heure
BACKUP_TIMESTAMP=$(date +"%Y%m%d_%H%M%S")
BACKUP_BASE="/usr/local/bin/ftp_video/backup"
BACKUP_DIR="${BACKUP_BASE}/${BACKUP_TIMESTAMP}"

# Cloner le dépôt
if git clone "https://github.com/Phips02/Bash.git" "$TEMP_DIR"; then
    print_log "info" "update" "Dépôt cloné avec succès"
    
    # Copier les fichiers
    cd "$TEMP_DIR/Telegram/Send_video_FTP" || {
        print_log "error" "update" "Impossible d'accéder au dossier des scripts"
        rm -rf "$TEMP_DIR"
        exit 1
    }
    
    # Sauvegarder les anciens scripts
    print_log "info" "update" "Création du backup dans $BACKUP_DIR"
    sudo -u telegram mkdir -p "$BACKUP_DIR"
    sudo cp /usr/local/bin/ftp_video/*.sh "$BACKUP_DIR/"
    
    # Changer les permissions du backup immédiatement après la copie
    sudo chown -R telegram:ftptelegram "$BACKUP_DIR"
    sudo chmod -R 770 "$BACKUP_DIR"
    
    # Copier les nouveaux scripts
    print_log "info" "update" "Copie des nouveaux scripts"
    if sudo cp *.sh /usr/local/bin/ftp_video/; then
        print_log "info" "update" "Scripts copiés avec succès"
        
        # Mettre à jour les permissions
        print_log "info" "update" "Mise à jour des permissions"
        sudo chmod 750 /usr/local/bin/ftp_video/*.sh
        sudo chown root:ftptelegram /usr/local/bin/ftp_video/*.sh
        
        print_log "info" "update" "Mise à jour terminée avec succès"
    else
        print_log "error" "update" "Erreur lors de la copie des scripts"
        print_log "info" "update" "Restauration du backup"
        sudo cp "$BACKUP_DIR"/*.sh /usr/local/bin/ftp_video/
    fi
else
    print_log "error" "update" "Erreur lors du clonage du dépôt"
fi

# Nettoyer les anciens backups (ne garder que les 2 plus récents)
print_log "info" "update" "Nettoyage des anciens backups"
cd "$BACKUP_BASE" || exit 1

# S'assurer que tous les dossiers ont les bonnes permissions
print_log "info" "update" "Correction des permissions des dossiers de backup"
if sudo chown -R telegram:ftptelegram "$BACKUP_BASE"/* && sudo chmod -R 770 "$BACKUP_BASE"/*; then
    print_log "info" "update" "Permissions corrigées avec succès"
else
    print_log "warning" "update" "Certains dossiers n'ont pas pu être modifiés (probablement appartenant à root)"
fi

# Supprimer les anciens backups
ls -1t | tail -n +3 | while read -r old_backup; do
    print_log "info" "update" "Tentative de suppression du backup: $old_backup"
    if rm -rf "$BACKUP_BASE/$old_backup" 2>/dev/null; then
        print_log "info" "update" "Backup supprimé avec succès: $old_backup"
    else
        print_log "warning" "update" "Impossible de supprimer le backup: $old_backup (permissions insuffisantes)"
    fi
done

print_log "info" "update" "Nettoyage des fichiers temporaires"
rm -rf "${TEMP_DIR}"

print_log "info" "update" "Processus de mise à jour terminé"
exit 0