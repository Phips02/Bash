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

# Vérifier et charger le fichier de configuration
CONFIG_DIR="/etc/backup_HDD"
CONFIG_FILE="$CONFIG_DIR/config.cfg"

# Créer le répertoire de configuration s'il n'existe pas
if [ ! -d "$CONFIG_DIR" ]; then
    print_log "INFO" "$LOG_FILENAME" "Création du répertoire de configuration: $CONFIG_DIR"
    mkdir -p "$CONFIG_DIR"
    if [ $? -ne 0 ]; then
        print_log "ERROR" "$LOG_FILENAME" "Impossible de créer le répertoire de configuration"
        exit 1
    fi
fi

# Créer le fichier de configuration s'il n'existe pas
if [ ! -f "$CONFIG_FILE" ]; then
    print_log "INFO" "$LOG_FILENAME" "Création du fichier de configuration par défaut: $CONFIG_FILE"
    cat > "$CONFIG_FILE" << EOL
# Configuration pour backup_HDD.sh
# Créé le : $(date +'%Y-%m-%d')

# Variables utilisateur et IP du serveur
user="User"
ssh_password='<MonMotDePasse>'
server_ip="0.0.0.0"
port="22"

# Nombre maximal de sauvegardes à conserver
max_backups=3

# Répertoires source à sauvegarder depuis le Synology
# Format: "user@ip:/chemin/dossier1" "user@ip:/chemin/dossier2"
source_directories=(
  "\$user@\$server_ip:/volume1/Proxmox/dump"
  "\$user@\$server_ip:/volume1/Proxmox/images"
)

# Répertoire de destination sur le Raspberry Pi
backup_directory="/mnt/backup"
EOL

    # Sécuriser le fichier de configuration (seul root peut le lire)
    chmod 600 "$CONFIG_FILE"
    
    print_log "WARNING" "$LOG_FILENAME" "Un fichier de configuration par défaut a été créé. Veuillez le modifier avec vos paramètres."
    echo "⚠️ Un fichier de configuration par défaut a été créé: $CONFIG_FILE"
    echo "Veuillez modifier ce fichier avec vos paramètres avant de continuer."
    exit 0
fi

# Charger le fichier de configuration
print_log "INFO" "$LOG_FILENAME" "Chargement du fichier de configuration: $CONFIG_FILE"
source "$CONFIG_FILE"

# Vérifier que les variables essentielles sont définies
if [ -z "$user" ] || [ -z "$server_ip" ] || [ -z "$ssh_password" ] || [ -z "${source_directories[0]}" ] || [ -z "$backup_directory" ]; then
    print_log "ERROR" "$LOG_FILENAME" "Configuration incomplète. Veuillez vérifier $CONFIG_FILE"
    echo "⚠️ Configuration incomplète. Veuillez vérifier $CONFIG_FILE"
    exit 1
fi

print_log "INFO" "$LOG_FILENAME" "Début du processus de sauvegarde"
print_log "DEBUG" "$LOG_FILENAME" "Nombre de répertoires à sauvegarder: ${#source_directories[@]}"

# Date du jour pour créer des répertoires de sauvegarde basés sur la date
date=$(date +'%Y-%m-%d_%H-%M-%S')
backup_start_time=$(date +%s)

# Créer un répertoire de sauvegarde avec la date sur le Raspberry Pi
mkdir -p "$backup_directory/backup_$date"
if [ $? -eq 0 ]; then
    print_log "INFO" "$LOG_FILENAME" "Répertoire de sauvegarde créé: $backup_directory/backup_$date"
else
    print_log "ERROR" "$LOG_FILENAME" "Impossible de créer le répertoire de sauvegarde"
    exit 1
fi

# Créer un fichier de statut pour suivre le backup
status_file="$backup_directory/backup_$date/.backup_status"
echo "status=running" > "$status_file"
echo "start_time=$backup_start_time" >> "$status_file"
echo "source_dirs=${#source_directories[@]}" >> "$status_file"
echo "completed_dirs=0" >> "$status_file"

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

print_log "INFO" "$LOG_FILENAME" "Taille totale estimée de la sauvegarde: ${total_backup_size} Go"

# Vérifier que l'espace disponible est suffisant pour la sauvegarde
if [ "$available_space_go" -lt "$total_backup_size" ]; then
    error_msg="Pas assez d'espace disponible. Espace manquant: $((total_backup_size - available_space_go)) Go"
    echo "ERROR: $error_msg"
    echo "→ Espace disponible : ${available_space_go} Go"
    echo "→ Taille estimée de la sauvegarde : ${total_backup_size} Go"
    print_log "CRITICAL" "$LOG_FILENAME" "$error_msg"
    echo "status=failed" > "$status_file"
    exit 1
fi

# Fonction améliorée pour le test de vitesse avec création d'un fichier temporaire de 1 GB
test_transfer_speed() {
    print_log "INFO" "$LOG_FILENAME" "Test de vitesse de transfert démarré"
    echo "⏱️ Test de vitesse de transfert en cours..."
    
    # Créer un répertoire temporaire pour le test
    test_dir="$backup_directory/backup_$date/speed_test"
    mkdir -p "$test_dir"
    
    # Fichier temporaire pour le test (utiliser le premier répertoire source)
    first_source=${source_directories[0]}
    remote_dir=$(echo "$first_source" | cut -d':' -f2)
    remote_user=$(echo "$first_source" | cut -d'@' -f1)
    remote_host=$(echo "$first_source" | cut -d'@' -f2 | cut -d':' -f1)
    test_file_remote="$remote_dir/test_speed.tmp"
    test_file_local="$test_dir/test_speed.tmp"
    
    # Créer un fichier de test de 1 GB sur le serveur distant
    print_log "DEBUG" "$LOG_FILENAME" "Création du fichier de test de 1 GB sur le serveur distant"
    echo "→ Création du fichier de test (1 GB) sur le serveur distant..."
    
    create_file_cmd="dd if=/dev/zero of=$test_file_remote bs=1M count=1024 oflag=dsync 2>/dev/null"
    sshpass -p "$ssh_password" ssh -p "$port" -o StrictHostKeyChecking=no "$remote_user@$remote_host" "$create_file_cmd"
    create_status=$?
    
    if [ $create_status -ne 0 ]; then
        print_log "ERROR" "$LOG_FILENAME" "Échec de la création du fichier de test sur le serveur distant"
        echo "⚠️ Échec de la création du fichier de test."
        rm -rf "$test_dir"
        return 1
    fi
    
    # Noter l'heure de début
    test_start_time=$(date +%s.%N)
    
    # Utiliser rsync pour tester la vitesse
    print_log "DEBUG" "$LOG_FILENAME" "Transfert du fichier de test de 1 GB: $test_file_remote vers $test_file_local"
    echo "→ Transfert du fichier de test de 1 GB en cours..."
    rsync_output=$(sshpass -p "$ssh_password" rsync -avz --stats -e "ssh -p $port -o StrictHostKeyChecking=no" "$remote_user@$remote_host:$test_file_remote" "$test_dir/" 2>&1)
    rsync_status=$?
    
    # Noter l'heure de fin
    test_end_time=$(date +%s.%N)
    
    # Vérifier si le transfert a réussi
    if [ $rsync_status -ne 0 ] || [ ! -f "$test_file_local" ]; then
        print_log "ERROR" "$LOG_FILENAME" "Échec du test de vitesse: ${rsync_output}"
        rm -rf "$test_dir"
        # Nettoyage du fichier distant même en cas d'échec
        sshpass -p "$ssh_password" ssh -p "$port" -o StrictHostKeyChecking=no "$remote_user@$remote_host" "rm -f $test_file_remote"
        return 1
    fi
    
    # Calculer la durée en secondes avec précision décimale
    test_duration=$(echo "$test_end_time - $test_start_time" | bc)
    
    # Extraire la taille du fichier et la vitesse de transfert depuis la sortie rsync
    file_size_bytes=$(stat -c %s "$test_file_local")
    file_size_mb=$(echo "scale=2; $file_size_bytes / 1048576" | bc)
    
    # Calculer la vitesse en MB/s
    transfer_speed_mbps=$(echo "scale=2; $file_size_mb / $test_duration" | bc)
    
    # Extraire les informations de statistiques rsync pour vérification
    bytes_sent=$(echo "$rsync_output" | grep "bytes/sec" | awk '{print $1}' | sed 's/,//g')
    speedup=$(echo "$rsync_output" | grep "speedup" | awk '{print $NF}')
    
    print_log "DEBUG" "$LOG_FILENAME" "Taille du fichier: ${file_size_mb}MB, Durée: ${test_duration}s, Vitesse: ${transfer_speed_mbps}MB/s"
    print_log "DEBUG" "$LOG_FILENAME" "Détails rsync: bytes=$bytes_sent, speedup=$speedup"
    
    # Supprimer le fichier téléchargé local
    rm -rf "$test_dir"
    
    # Supprimer le fichier de test sur le serveur distant
    print_log "DEBUG" "$LOG_FILENAME" "Suppression du fichier de test sur le serveur distant"
    sshpass -p "$ssh_password" ssh -p "$port" -o StrictHostKeyChecking=no "$remote_user@$remote_host" "rm -f $test_file_remote"
    
    # Estimation du temps total basée sur la vitesse mesurée
    total_size_mb=$((total_backup_size * 1024))
    estimated_duration_s=$(echo "scale=0; $total_size_mb / $transfer_speed_mbps" | bc)
    
    # Convertir en heures et minutes
    estimated_hours=$((estimated_duration_s / 3600))
    estimated_minutes=$(( (estimated_duration_s % 3600) / 60 ))
    
    # Calculer la date et l'heure estimées de fin
    current_timestamp=$(date +%s)
    estimated_end_timestamp=$((current_timestamp + estimated_duration_s))
    estimated_end_datetime=$(date -d "@$estimated_end_timestamp" +'%Y-%m-%d %H:%M:%S')
    
    # Sauvegarder l'estimation dans le fichier de statut
    echo "estimated_duration_s=$estimated_duration_s" >> "$status_file"
    echo "transfer_speed_mbps=$transfer_speed_mbps" >> "$status_file"
    echo "test_file_size_mb=$file_size_mb" >> "$status_file"
    echo "estimated_end_datetime=$estimated_end_datetime" >> "$status_file"
    
    # Afficher l'estimation
    echo "✅ Test de vitesse terminé:"
    echo "→ Vitesse de transfert: $transfer_speed_mbps MB/s"
    echo "→ Temps estimé: ${estimated_hours}h ${estimated_minutes}m pour $total_backup_size Go"
    echo "→ Fin estimée: $estimated_end_datetime"

    estimate_msg="%0ATemps estimé: ${estimated_hours}h ${estimated_minutes}m %0A(vitesse: $transfer_speed_mbps MB/s). %0AFin prévue: $estimated_end_datetime"

    print_log "INFO" "$LOG_FILENAME" "Test de vitesse réussi: $estimate_msg"
    return 0
}

# Appel de la fonction améliorée et gestion des erreurs
if ! test_transfer_speed; then
    print_log "WARNING" "$LOG_FILENAME" "Test de vitesse échoué, utilisation d'une valeur par défaut"
    echo "⚠️ ATTENTION: Test de vitesse échoué. Utilisation d'une valeur par défaut."
    
    # Utiliser une estimation conservatrice par défaut
    transfer_speed_mbps=10
    
    # Estimer la durée totale (en secondes)
    total_size_mb=$((total_backup_size * 1024))
    estimated_duration_s=$(echo "scale=0; $total_size_mb / $transfer_speed_mbps" | bc)
    
    # Convertir en heures et minutes
    estimated_hours=$((estimated_duration_s / 3600))
    estimated_minutes=$(( (estimated_duration_s % 3600) / 60 ))
    
    # Calculer la date et l'heure estimées de fin
    current_timestamp=$(date +%s)
    estimated_end_timestamp=$((current_timestamp + estimated_duration_s))
    estimated_end_datetime=$(date -d "@$estimated_end_timestamp" +'%Y-%m-%d %H:%M:%S')


    # Sauvegarder l'estimation dans le fichier de statut
    echo "estimated_duration_s=$estimated_duration_s" >> "$status_file"
    echo "transfer_speed_mbps=$transfer_speed_mbps" >> "$status_file"
    echo "estimated_end_datetime=$estimated_end_datetime" >> "$status_file"
    
    # Afficher l'estimation
    echo "⚠️ Estimation par défaut:"
    echo "→ Vitesse de transfert supposée: $transfer_speed_mbps MB/s"
    echo "→ Temps estimé: ${estimated_hours}h ${estimated_minutes}m pour $total_backup_size Go"
    echo "→ Fin estimée: $estimated_end_datetime"

    estimate_msg="%0ATemps estimé: ${estimated_hours}h ${estimated_minutes}m %0A(vitesse: $transfer_speed_mbps MB/s). %0AFin prévue: $estimated_end_datetime"
fi

# ✅ Afficher un message de confirmation avant de lancer la sauvegarde
echo "✅ Vérification OK :"
echo "→ Taille estimée de la sauvegarde : ${total_backup_size} Go"
echo "→ Espace disponible avant la sauvegarde : ${available_space_go} Go"
echo "🔄 Démarrage de la sauvegarde..."

# Notifier le début de la sauvegarde avec l'estimation (via le logger existant)
print_log "WARNING" "$LOG_FILENAME" "%0ADémarrage sauvegarde: ${total_backup_size} Go. $estimate_msg"
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

# Compteur pour les directories complétées
completed_dirs=0
failed_dirs=0
backup_real_start=$(date +%s)

# Fonction pour vérifier l'accessibilité d'un répertoire
check_directory_access() {
    local remote_dir="$1"
    local remote_path=$(echo "$remote_dir" | cut -d':' -f2)
    
    print_log "DEBUG" "$LOG_FILENAME" "Vérification de l'accès au répertoire: $remote_path"
    
    # Test d'accès avec timeout pour éviter de bloquer
    timeout 10s sshpass -p "$ssh_password" ssh -p "$port" -o StrictHostKeyChecking=no "$user@$server_ip" "ls -la $remote_path" >/dev/null 2>&1
    
    return $?
}

# Effectuer la sauvegarde avec rsync depuis le Synology vers le Raspberry Pi
for source_directory in "${source_directories[@]}"; do
    dir_name=$(basename $(echo "$source_directory" | cut -d':' -f2))
    echo "📂 Sauvegarde du répertoire $dir_name..."
    print_log "INFO" "$LOG_FILENAME" "Début sauvegarde: $dir_name ($((completed_dirs+1))/${#source_directories[@]})"
    
    # Vérifier l'accessibilité du répertoire avant de tenter la sauvegarde
    if ! check_directory_access "$source_directory"; then
        print_log "ERROR" "$LOG_FILENAME" "Répertoire inaccessible: $dir_name - Sauvegarde ignorée"
        echo "⚠️ Répertoire inaccessible: $dir_name - Sauvegarde ignorée"
        failed_dirs=$((failed_dirs + 1))
        continue
    fi
    
    # Garder un log détaillé de rsync
    rsync_log="$backup_directory/backup_$date/rsync_${dir_name}.log"
    
    # On retire l'option -q pour avoir plus d'informations sur l'avancement
    sshpass -p "$ssh_password" rsync -avz --delete --stats \
        --log-file="$rsync_log" \
        -e "ssh -p $port -o StrictHostKeyChecking=no" \
        "$source_directory" "$backup_directory/backup_$date"
    
    rsync_status=$?
    if [ $rsync_status -eq 0 ]; then
        print_log "INFO" "$LOG_FILENAME" "Sauvegarde réussie pour: $dir_name"
        completed_dirs=$((completed_dirs + 1))
        echo "completed_dirs=$completed_dirs" >> "$status_file"
        
        # Calculer la progression
        progress=$((completed_dirs * 100 / ${#source_directories[@]}))
        
        # Calculer le temps écoulé et estimer le temps restant
        current_time=$(date +%s)
        elapsed_time=$((current_time - backup_real_start))
        
        if [ $completed_dirs -gt 0 ] && [ $completed_dirs -lt ${#source_directories[@]} ]; then
            # Estimer le temps restant basé sur le temps écoulé et la progression
            remaining_dirs=$((${#source_directories[@]} - completed_dirs))
            time_per_dir=$((elapsed_time / completed_dirs))
            remaining_time=$((time_per_dir * remaining_dirs))
            
            # Convertir en heures et minutes
            remaining_hours=$((remaining_time / 3600))
            remaining_minutes=$(( (remaining_time % 3600) / 60 ))
            
            # Si c'est une longue sauvegarde et qu'on avance bien, on envoie une notification de progression
            progress_msg="Progression: $progress% ($completed_dirs/${#source_directories[@]}). Temps restant estimé: ${remaining_hours}h ${remaining_minutes}m"
            print_log "INFO" "$LOG_FILENAME" "$progress_msg"
        fi
    else
        print_log "ERROR" "$LOG_FILENAME" "Échec de la sauvegarde pour: $dir_name (code: $rsync_status)"
        failed_dirs=$((failed_dirs + 1))
    fi
done

# Finaliser le statut
backup_end_time=$(date +%s)
backup_duration=$((backup_end_time - backup_start_time))
hours=$((backup_duration / 3600))
minutes=$(( (backup_duration % 3600) / 60 ))

# Mise à jour du fichier de statut
if [ $failed_dirs -eq 0 ]; then
    echo "status=completed" >> "$status_file"
else
    echo "status=partial" >> "$status_file"
fi
echo "end_time=$backup_end_time" >> "$status_file"
echo "duration=$backup_duration" >> "$status_file"
echo "failed_dirs=$failed_dirs" >> "$status_file"

# ✅ Afficher un message de fin de sauvegarde
echo "✅ Sauvegarde terminée le $(date)."
if [ $failed_dirs -gt 0 ]; then
    echo "⚠️ Attention: $failed_dirs répertoires n'ont pas pu être sauvegardés correctement."
fi
echo "⏱️ Durée totale: ${hours}h ${minutes}m"
echo "📊 Espace disponible après la sauvegarde :"
df -h "$backup_directory"

# Calculer l'espace restant après la sauvegarde
remaining_space=$(df --output=avail "$backup_directory" | tail -n 1)
remaining_space_go=$((remaining_space / 1024 / 1024))

# Notification finale (via le logger existant)
if [ $failed_dirs -eq 0 ]; then
    print_log "WARNING" "$LOG_FILENAME" "BACKUP TERMINÉ ✅ - Durée: ${hours}h ${minutes}m. Espace: ${remaining_space_go} Go"
else
    print_log "ERROR" "$LOG_FILENAME" "BACKUP PARTIEL ⚠️ - $failed_dirs échecs. Durée: ${hours}h ${minutes}m"
fi

# Créer un lien symbolique vers la dernière sauvegarde pour faciliter l'accès
rm -f "$backup_directory/latest" 2>/dev/null
ln -s "$backup_directory/backup_$date" "$backup_directory/latest"
