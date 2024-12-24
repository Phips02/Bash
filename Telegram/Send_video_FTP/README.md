#Phips
#Version : 2024.03.24 11:00


# Système d'envoi automatique de vidéos FTP vers Telegram

## Structure des dossiers
```
/etc/telegram/ftp_video/
└── ftp_config.cfg              # Configuration centralisée

/usr/local/bin/ftp_video/
├── phips_logger.sh            # Système de logging
├── ftp_telegram.sh           # Script principal
├── telegram.functions.sh     # Fonctions Telegram
├── cleanup.sh               # Script de maintenance
└── ftp_monitor.sh          # Script de surveillance

/var/tmp/
├── FTP_TEMP/               # Fichiers temporaires
└── FTP_FILES_SEEN.txt      # Cache des fichiers traités

/var/log/ftp_telegram/      # Logs quotidiens
```

## Déploiement depuis GitHub

### 1. Installation des dépendances
```bash
sudo apt update
sudo apt install lftp curl git
```

### 2. Cloner le dépôt et déployer
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

# Configurer les permissions
sudo chmod 755 /usr/local/bin/ftp_video
sudo chmod 755 /var/log/ftp_telegram
sudo chmod 755 /var/tmp/FTP_TEMP
sudo chmod 600 /etc/telegram/ftp_video/ftp_config.cfg
sudo chmod +x /usr/local/bin/ftp_video/*.sh
sudo touch /var/tmp/FTP_FILES_SEEN.txt
sudo chmod 666 /var/tmp/FTP_FILES_SEEN.txt

# Sécuriser les fichiers
sudo groupadd ftptelegram
sudo usermod -a -G ftptelegram $USER
sudo chown root:ftptelegram /etc/telegram/ftp_video/ftp_config.cfg
sudo chmod 640 /etc/telegram/ftp_video/ftp_config.cfg
sudo chown root:ftptelegram /usr/local/bin/ftp_video/*.sh
sudo chmod 750 /usr/local/bin/ftp_video/*.sh
sudo chown root:ftptelegram /var/tmp/FTP_TEMP
sudo chmod 775 /var/tmp/FTP_TEMP
sudo chown root:ftptelegram /var/log/ftp_telegram
sudo chmod 775 /var/log/ftp_telegram
sudo chown root:ftptelegram /var/tmp/FTP_FILES_SEEN.txt
sudo chmod 664 /var/tmp/FTP_FILES_SEEN.txt

# Nettoyer
cd ../..
rm -rf Bash
```

### 3. Configuration du bot
```bash
# Éditer la configuration
sudo nano /etc/telegram/ftp_video/ftp_config.cfg
```

### 4. Configuration du CRON
```bash
# Ouvrir l'éditeur crontab
sudo crontab -e

# Ajouter ces lignes
@reboot /usr/local/bin/ftp_video/ftp_monitor.sh &
*/5 * * * * if ! pgrep -f "ftp_monitor.sh" > /dev/null; then /usr/local/bin/ftp_video/ftp_monitor.sh & fi
0 0 * * * /usr/local/bin/ftp_video/cleanup.sh
```

### 5. Démarrage du service
```bash
# Se connecter au groupe (nécessaire après l'installation)
newgrp ftptelegram

# Démarrage manuel
/usr/local/bin/ftp_video/ftp_monitor.sh &

# Vérification
ps aux | grep ftp_monitor
tail -f /var/log/ftp_telegram/ftp_telegram_$(date +%Y-%m-%d).log
```

### 6. Commandes utiles
```bash
# Arrêt
pkill -f "ftp_monitor.sh"

# Nettoyage manuel
/usr/local/bin/ftp_video/cleanup.sh

# Test du logger
source /usr/local/bin/ftp_video/phips_logger.sh
print_log "info" "test" "Test du système"
```

### 7. Mise à jour depuis GitHub
```bash
cd /tmp
git clone https://github.com/Phips02/Bash.git
cd Bash/Telegram/Send_video_FTP
sudo cp *.sh /usr/local/bin/ftp_video/
sudo chmod +x /usr/local/bin/ftp_video/*.sh
cd ../..
rm -rf Bash
```

## Licence
Ce projet est sous licence GNU GPLv3 - voir le fichier [LICENSE](LICENSE) pour plus de détails.

Cette licence :
- Permet l'utilisation privée
- Permet la modification
- Oblige le partage des modifications sous la même licence
- Interdit l'utilisation commerciale fermée
- Oblige à partager le code source