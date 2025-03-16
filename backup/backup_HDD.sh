#!/bin/bash

# Définir un nom de fichier de log personnalisé (AVANT d'importer le logger)
LOG_FILENAME="backup_HDD"

# Importer le logger
LOGGER_PATH="/usr/local/bin/phips_logger/universal_logger.sh"
if [ -f "$LOGGER_PATH" ]; then
    source "$LOGGER_PATH"
    print_log "INFO" "$LOG_FILENAME" "Logger chargé avec succès"
else
    echo "Logger non trouvé: $LOGGER_PATH"
    exit 1
fi

# Variables utilisateur et IP du serveur
user="User"
ssh_password='<MonMotDePasse>'

server_ip="0.0.0.0"
port="22"

max_backups=3

# Répertoires source à sauvegarder sur le Synology
source_directories=("$user@$server_ip:/volume1/Proxmox/dump" "$user@$server_ip:/volume1/Proxmox/images")  # Liste des répertoires à sauvegarder






print_log "WARNING" "$LOG_FILENAME" "Début du processus de sauvegarde"
print_log "DEBUG" "$LOG_FILENAME" "Nombre de répertoires à sauvegarder: ${#source_directories[@]}"

# Répertoire de destination sur le Raspberry Pi
backup_directory="/mnt/backup"

# Date du jour pour créer des répertoires de sauvegarde basés sur la date
date=$(date +'%Y-%m-%d_%H-%M-%S')

# Créer un répertoire de sauvegarde avec la date sur le Raspberry Pi
mkdir -p "$backup_directory/backup_$date"
if [ $? -eq 0 ]; then
    print_log "INFO" "$LOG_FILENAME" "Répertoire de sauvegarde créé: $backup_directory/backup_$date"
else
    print_log "ERROR" "$LOG_FILENAME" "Impossible de créer le répertoire de sauvegarde"
    exit 1
fi

# Calculer l'espace disponible sur /mnt/backup en Go
available_space=$(df --output=avail "$backup_directory" | tail -n 1)
available_space_go=$((available_space / 1024 / 1024))
print_log "DEBUG" "$LOG_FILENAME" "Espace disponible: ${available_space_go} Go"

# Calculer la taille totale des répertoires source en Go
total_backup_size=0
for source_directory in "${source_directories[@]}"; do
    remote_path=$(echo "$source_directory" | cut -d':' -f2) 
    dir_size=$(sshpass -p "$ssh_password" ssh -p "$port" -o StrictHostKeyChecking=no "$user@$server_ip" "du -s --block-size=1G $remote_path" | awk '{print $1}')
    
    if [ $? -ne 0 ]; then
        print_log "WARNING" "$LOG_FILENAME" "Échec de la récupération de la taille pour $source_directory"
    else
        print_log "DEBUG" "$LOG_FILENAME" "Taille du répertoire $remote_path: ${dir_size} Go"
        total_backup_size=$((total_backup_size + dir_size))
    fi
done

print_log "WARNING" "$LOG_FILENAME" "Taille totale estimée de la sauvegarde: ${total_backup_size} Go"

# Vérifier que l'espace disponible est suffisant pour la sauvegarde
if [ "$available_space_go" -lt "$total_backup_size" ]; then
    echo "ERROR: Pas assez d'espace disponible sur /mnt/backup pour la sauvegarde."
    echo "→ Espace disponible : ${available_space_go} Go"
    echo "→ Taille estimée de la sauvegarde : ${total_backup_size} Go"
    echo "→ Espace manquant : $((total_backup_size - available_space_go)) Go"
    print_log "CRITICAL" "$LOG_FILENAME" "Pas assez d'espace disponible. Espace manquant: $((total_backup_size - available_space_go)) Go"
    exit 1
fi

# ✅ Afficher un message de confirmation avant de lancer la sauvegarde
echo "✅ Vérification OK :"
echo "→ Taille estimée de la sauvegarde : ${total_backup_size} Go"
echo "→ Espace disponible avant la sauvegarde : ${available_space_go} Go"
echo "🔄 Démarrage de la sauvegarde..."

print_log "INFO" "$LOG_FILENAME" "Vérification d'espace réussie. Démarrage de la sauvegarde"

# Supprimer les anciennes sauvegardes si le nombre dépasse la limite
backup_count=$(ls -1 "$backup_directory" | grep -E "^backup_" | wc -l)
print_log "DEBUG" "$LOG_FILENAME" "Nombre de sauvegardes existantes: $backup_count (max: $max_backups)"

if [ "$backup_count" -ge "$max_backups" ]; then
    print_log "INFO" "$LOG_FILENAME" "Suppression des anciennes sauvegardes pour respecter la limite de $max_backups"
    # Supprimer les sauvegardes les plus anciennes
    old_backups=$(ls -1 "$backup_directory" | grep -E "^backup_" | sort | head -n $(($backup_count - $max_backups)))
    for old_backup in $old_backups; do
        echo "→ Sauvegardes conservées : $max_backups"
        echo "🗑 Suppression de l'ancienne sauvegarde : $old_backup"
        print_log "INFO" "$LOG_FILENAME" "Suppression de l'ancienne sauvegarde: $old_backup"
        rm -rf "$backup_directory/$old_backup"
        if [ $? -ne 0 ]; then
            print_log "WARNING" "$LOG_FILENAME" "Problème lors de la suppression de $old_backup"
        fi
    done
fi

# Effectuer la sauvegarde avec rsync depuis le Synology vers le Raspberry Pi
for source_directory in "${source_directories[@]}"; do
    echo "📂 Sauvegarde du répertoire $source_directory..."
    print_log "INFO" "$LOG_FILENAME" "Début de la sauvegarde du répertoire: $source_directory"
    
    # Modification ici : ajout de l'option -o StrictHostKeyChecking=no
    sshpass -p "$ssh_password" rsync -avzq --delete -e "ssh -p $port -o StrictHostKeyChecking=no" "$source_directory" "$backup_directory/backup_$date"
    
    if [ $? -eq 0 ]; then
        print_log "INFO" "$LOG_FILENAME" "Sauvegarde réussie pour: $source_directory"
    else
        print_log "ERROR" "$LOG_FILENAME" "Échec de la sauvegarde pour: $source_directory"
    fi
done

# ✅ Afficher un message de fin de sauvegarde
echo "✅ Sauvegarde terminée avec succès le $date."
echo "📊 Espace disponible après la sauvegarde :"
df -h "$backup_directory"

# Calculer l'espace restant après la sauvegarde
remaining_space=$(df --output=avail "$backup_directory" | tail -n 1)
remaining_space_go=$((remaining_space / 1024 / 1024))
print_log "INFO" "$LOG_FILENAME" "Sauvegarde terminée avec succès. Espace restant: ${remaining_space_go} Go"
print_log "WARNING" "$LOG_FILENAME" "Processus de sauvegarde terminé"
