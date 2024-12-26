#Phips
#Version : 2024.03.24 14:00


# Système d'envoi automatique de vidéos FTP vers Telegram

## Structure des dossiers
```
/etc/telegram/ftp_video/
└── ftp_config.cfg              # Configuration centralisée

/usr/local/bin/ftp_video/
├── phips_logger.sh             # Système de logging
├── ftp_telegram.sh             # Script principal
├── telegram.functions.sh       # Fonctions Telegram
├── cleanup.sh                  # Script de maintenance
├── check_and_start.sh          # Script de vérification du moniteur
├── ftp_monitor.sh              # Script de surveillance
├── update.sh                   # Script de mise à jour
└── backup/                     # Dossier de sauvegarde pour les mises à jour
    └── YYYYMMDD_HHMMSS/        # Sous-dossiers de backup horodatés

/var/tmp/
├── FTP_TEMP/                   # Fichiers temporaires
└── FTP_FILES_SEEN.txt          # Cache des fichiers traités

/var/log/ftp_telegram/          # Logs quotidiens
```

## Déploiement depuis GitHub

### 1. Préparation du système
```bash
# Installation des dépendances
apt update
apt install sudo lftp curl git -y

# Création de l'utilisateur telegram
sudo useradd -m -s /bin/bash telegram

# Définir un mot de passe pour l'utilisateur telegram
sudo passwd telegram

# Ajouter l'utilisateur telegram au groupe sudo
sudo usermod -aG sudo telegram

# Création du groupe ftptelegram et ajout des utilisateurs
sudo groupadd ftptelegram
sudo usermod -a -G ftptelegram telegram
sudo usermod -a -G ftptelegram $USER  # Ajoute aussi l'utilisateur courant
```

### 2. Se connecter en tant qu'utilisateur telegram
```bash
# Se connecter avec le nouvel utilisateur
su - telegram

# Vérifier les groupes
groups

# Aller dans le répertoire home de l'utilisateur telegram
cd ~

# Vérifier qu'on est bien dans le bon répertoire
pwd  # Devrait afficher /home/telegram
```

### 3. Cloner le dépôt et déployer
```bash
# Cloner le dépôt
git clone https://github.com/Phips02/Bash.git
cd Bash/Telegram/Send_video_FTP

# Créer les dossiers nécessaires
sudo mkdir -p /etc/telegram/ftp_video
sudo mkdir -p /usr/local/bin/ftp_video
sudo mkdir -p /var/tmp/FTP_TEMP
sudo mkdir -p /var/log/ftp_telegram

# Copier les fichiers
sudo cp ftp_config.cfg /etc/telegram/ftp_video/
sudo cp *.sh /usr/local/bin/ftp_video/
```

### 4. Configuration des permissions et sécurité
```bash
# --- Permissions des répertoires principaux ---
# Répertoire des binaires : lecture et exécution pour le groupe
sudo chmod 750 /usr/local/bin/ftp_video

# Répertoire des logs : écriture complète pour le groupe (important pour la création des logs)
sudo chmod 775 /var/log/ftp_telegram

# Répertoire temporaire : écriture pour le groupe, lecture pour les autres
sudo chmod 775 /var/tmp/FTP_TEMP

# --- Permissions des fichiers ---
# Scripts : exécutables uniquement par root et le groupe
sudo find /usr/local/bin/ftp_video -type f -name "*.sh" -exec chmod 750 {} \;

# Configuration : lecture seule pour le groupe, invisible pour les autres
sudo find /etc/telegram/ftp_video -type f -exec chmod 640 {} \;

# Fichier de cache : lecture/écriture pour le groupe, lecture seule pour les autres
sudo touch /var/tmp/FTP_FILES_SEEN.txt
sudo chmod 664 /var/tmp/FTP_FILES_SEEN.txt

# --- Création du premier fichier de log ---
sudo touch /var/log/ftp_telegram/ftp_telegram_$(date +%Y-%m-%d).log
sudo chmod 664 /var/log/ftp_telegram/ftp_telegram_$(date +%Y-%m-%d).log

# --- Attribution des propriétaires ---
# Configuration
sudo chown -R root:ftptelegram /etc/telegram/ftp_video

# Scripts
sudo chown -R root:ftptelegram /usr/local/bin/ftp_video

# Dossiers de travail
sudo chown root:ftptelegram /var/tmp/FTP_TEMP
sudo chown -R root:ftptelegram /var/log/ftp_telegram
sudo chown root:ftptelegram /var/tmp/FTP_FILES_SEEN.txt

# Script de mise à jour
sudo chmod 750 /usr/local/bin/ftp_video/update.sh
sudo chown root:ftptelegram /usr/local/bin/ftp_video/update.sh

# --- Vérification des permissions ---
ls -la /usr/local/bin/ftp_video
ls -la /etc/telegram/ftp_video
ls -la /var/tmp/FTP_TEMP
ls -la /var/log/ftp_telegram
ls -la /var/tmp/FTP_FILES_SEEN.txt

# Nettoyer
cd ~           # Retourner au répertoire home
rm -rf Bash    # Supprimer le dossier Bash
```

### 5. Configuration du bot
```bash
# Éditer la configuration
sudo nano /etc/telegram/ftp_video/ftp_config.cfg
```

### 6. Configuration du CRON
```bash
# Ouvrir l'éditeur crontab
sudo crontab -e

# Ajouter ces lignes
@reboot /usr/local/bin/ftp_video/ftp_monitor.sh &
*/10 * * * * /usr/local/bin/ftp_video/check_and_start.sh
0 0 * * * /usr/local/bin/ftp_video/cleanup.sh
```

### 7. Démarrage du service
```bash
# Se connecter au groupe (nécessaire après l'installation)
newgrp ftptelegram

# Démarrage manuel
/usr/local/bin/ftp_video/ftp_monitor.sh > /dev/null 2>&1 & disown

# Vérification
ps aux | grep ftp_monitor
tail -f /var/log/ftp_telegram/ftp_telegram_$(date +%Y-%m-%d).log
```

### 8. Commandes utiles
```bash
# Arrêt
sudo pkill -f "ftp_monitor.sh"

# Nettoyage manuel
/usr/local/bin/ftp_video/cleanup.sh

# Test du logger
source /usr/local/bin/ftp_video/phips_logger.sh
print_log "info" "test" "Test du système"
tail -n 20 /var/log/ftp_telegram/ftp_telegram_$(date +%Y-%m-%d).log
```

### 9. Mise à jour depuis GitHub

#### Méthode manuelle
```bash
cd /tmp
git clone https://github.com/Phips02/Bash.git
cd Bash/Telegram/Send_video_FTP
sudo cp *.sh /usr/local/bin/ftp_video/
sudo chmod +x /usr/local/bin/ftp_video/*.sh
cd ../..
rm -rf Bash
```

#### Méthode automatique (recommandée)
```bash
# Lancer le script de mise à jour
sudo /usr/local/bin/ftp_video/update.sh

# Vérifier les logs de mise à jour
tail -f /var/log/ftp_telegram/ftp_telegram_$(date +%Y-%m-%d).log
```

Le script de mise à jour automatique :
- Crée une sauvegarde horodatée des scripts existants dans le dossier backup
- Met à jour depuis GitHub
- Gère les permissions
- Restaure la sauvegarde en cas d'erreur
- Conserve uniquement les 2 backups les plus récents

## Licence
Ce projet est sous licence GNU GPLv3 - voir le fichier [LICENSE](LICENSE) pour plus de détails.

Cette licence :
- Permet l'utilisation privée
- Permet la modification
- Oblige le partage des modifications sous la même licence
- Interdit l'utilisation commerciale fermée
- Oblige à partager le code source