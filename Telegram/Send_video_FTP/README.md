#Phips
#Version : 2024.12.26 21:00


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
groups telegram

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
sudo find /usr/local/bin/ftp_video -maxdepth 1 -type f -name "*.sh" -exec chown root:ftptelegram {} \;

# Répertoire des logs : écriture complète pour le groupe
sudo chmod 775 /var/log/ftp_telegram
sudo chown -R telegram:ftptelegram /var/log/ftp_telegram

# Répertoire temporaire : écriture pour le groupe
sudo chmod 775 /var/tmp/FTP_TEMP
sudo chown root:ftptelegram /var/tmp/FTP_TEMP

# Répertoire de backup : accès complet pour l'utilisateur telegram
sudo mkdir -p /usr/local/bin/ftp_video/backup
sudo chown -R telegram:ftptelegram /usr/local/bin/ftp_video/backup
sudo chmod -R 770 /usr/local/bin/ftp_video/backup

# --- Permissions des fichiers ---
# Scripts : exécutables uniquement par root et le groupe
sudo find /usr/local/bin/ftp_video -type f -name "*.sh" -exec chmod 750 {} \;
sudo chown root:ftptelegram /usr/local/bin/ftp_video/*.sh

# Configuration : lecture seule pour le groupe
sudo find /etc/telegram/ftp_video -type f -exec chmod 640 {} \;
sudo chown -R root:ftptelegram /etc/telegram/ftp_video

# Fichiers de travail
sudo touch /var/tmp/FTP_FILES_SEEN.txt
sudo chmod 664 /var/tmp/FTP_FILES_SEEN.txt
sudo chown telegram:ftptelegram /var/tmp/FTP_FILES_SEEN.txt

# Création du premier fichier de log
sudo touch /var/log/ftp_telegram/ftp_telegram_$(date +%Y-%m-%d).log
sudo chmod 664 /var/log/ftp_telegram/ftp_telegram_$(date +%Y-%m-%d).log
sudo chown telegram:ftptelegram /var/log/ftp_telegram/ftp_telegram_$(date +%Y-%m-%d).log

# --- Vérification des permissions ---
ls -la /usr/local/bin/ftp_video
ls -la /usr/local/bin/ftp_video/backup
ls -la /etc/telegram/ftp_video
ls -la /var/tmp/FTP_TEMP
ls -la /var/log/ftp_telegram
ls -la /var/tmp/FTP_FILES_SEEN.txt

# Configuration de sudo pour le script de mise à jour
sudo rm /etc/sudoers.d/ftp_video
echo "# Permettre l'exécution du script update.sh sans mot de passe" | sudo tee /etc/sudoers.d/ftp_video
echo "%ftptelegram ALL=(ALL) NOPASSWD: /usr/local/bin/ftp_video/update.sh" | sudo tee -a /etc/sudoers.d/ftp_video
sudo chmod 440 /etc/sudoers.d/ftp_video
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

⚠️ **Note importante** : Après l'installation initiale ou une mise à jour majeure, il est recommandé de redémarrer le serveur pour s'assurer que tous les services sont correctement initialisés et que les logs fonctionnent correctement.

```bash
# Redémarrer le serveur
sudo reboot
```

### 8. Commandes utiles
```bash
# Arrêt
sudo pkill -f "ftp_monitor.sh"

# Nettoyage manuel
/usr/local/bin/ftp_video/cleanup.sh

# Test du logger
source /usr/local/bin/ftp_video/phips_logger.sh

# Tests des différents niveaux de notification
print_log "debug" "test" "Message de test DEBUG 🔍"
print_log "info" "test" "Message de test INFO ℹ️"
print_log "warning" "test" "Message de test WARNING ⚠️"
print_log "error" "test" "Message de test ERROR ❌"
print_log "critical" "test" "Message de test CRITICAL 🚨"

# Vérifier les logs
tail -n 20 /var/log/ftp_telegram/ftp_telegram_$(date +%Y-%m-%d).log

# Vérifier les notifications Telegram
# Les notifications apparaîtront dans votre chat Telegram selon le NOTIFICATION_LEVEL configuré
```

### 9. Mise à jour depuis GitHub

#### Méthode manuelle
```bash
cd /tmp
rm -rf Bash
git clone https://github.com/Phips02/Bash.git
cd Bash/Telegram/Send_video_FTP
sudo cp *.sh /usr/local/bin/ftp_video/
sudo chmod +x /usr/local/bin/ftp_video/*.sh
cd /tmp
rm -rf Bash
```

#### Méthode automatique (recommandée)
```bash
# Lancer le script de mise à jour (doit être exécuté avec sudo)
sudo /usr/local/bin/ftp_video/update.sh

# Vérifier les logs de mise à jour
tail -f /var/log/ftp_telegram/ftp_telegram_$(date +%Y-%m-%d).log
```

Le script de mise à jour automatique :
- Crée une sauvegarde horodatée des scripts existants dans le dossier backup
- Met à jour depuis GitHub
- Gère les permissions des fichiers et dossiers
- Restaure la sauvegarde en cas d'erreur
- Conserve uniquement les 2 backups les plus récents
- Gère les erreurs de permissions avec des logs appropriés

## Licence
Ce projet est sous licence GNU GPLv3 - voir le fichier [LICENSE](LICENSE) pour plus de détails.

Cette licence :
- Permet l'utilisation privée
- Permet la modification
- Oblige le partage des modifications sous la même licence
- Interdit l'utilisation commerciale fermée
- Oblige à partager le code source