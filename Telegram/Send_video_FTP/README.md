#Phips
#Version : 2024.03.24 10:20


# Système d'envoi automatique de vidéos FTP vers Telegram

## Description
Ce système permet de récupérer automatiquement des fichiers vidéo (.mkv) depuis un serveur FTP et de les envoyer vers un groupe Telegram. Le système parcourt récursivement les sous-dossiers du FTP pour traiter tous les fichiers vidéo.

## Description des scripts

### 1. ftp_config.cfg
Fichier de configuration centralisé situé dans `/etc/telegram/ftp_video/ftp_config.cfg`
- Configuration du serveur FTP (host, port, credentials)
- Configuration Telegram (bot token, chat ID)
- Configuration des chat IDs par client :
  ```bash
  CLIENT_CHAT_IDS_Client_1="-111111111"  # Le dossier doit avoir le nom du client (Client_1)
  CLIENT_CHAT_IDS_Client_2="-222222222"  # Le dossier doit avoir le nom du client (Client_2)
  ```
- Configuration des chemins d'accès :
  - BASE_DIR : Répertoire de base pour les scripts
  - CONFIG_BASE_DIR : Répertoire de base pour la configuration
  - LOG_DIR : Répertoire des logs
  - TEMP_DIR : Répertoire temporaire
  - STATE_FILE : Fichier d'état
  - TELEGRAM_FUNCTIONS : Chemin vers les fonctions Telegram
  - LOGGER_PATH : Chemin vers le logger

### 2. ftp_telegram.sh
Script principal situé dans `${BASE_DIR}/ftp_telegram.sh`
- Utilisation des chemins définis dans ftp_config.cfg
- Vérification complète de la configuration et des dépendances
- Chargement et vérification du logger et des fonctions Telegram
- Gestion des erreurs améliorée avec logs détaillés
- Traitement récursif des dossiers FTP avec exclusion des dossiers système (@eaDir, @tmp)
- Système de retry pour l'envoi Telegram (3 tentatives avec délai de 5 secondes)
- Gestion des descriptions avec nom du dossier source et nom du fichier
- Nettoyage automatique des fichiers temporaires
- Utilisation de la fonction `print_log` pour une gestion cohérente des logs
- Support multi-clients avec détection automatique basée sur le nom du dossier

### 3. telegram.functions.sh
Bibliothèque de fonctions Telegram dans `${BASE_DIR}/telegram.functions.sh`
- Validation du token Telegram avec système de retry
- Gestion des messages Telegram avec support HTML
- Fonctions d'échappement HTML pour les messages
- Gestion des erreurs de communication détaillée
- Test de connexion intégré
- Fonctions pour l'envoi de texte et vidéo
- Support du mode HTML pour le formatage des messages

### 4. phips_logger.sh
Système de logging centralisé dans `${LOGGER_PATH}`
- Support de plusieurs niveaux de log (DEBUG, INFO, NOTICE, WARNING, ERROR, CRITICAL)
- Rotation automatique des logs par date
- Gestion des erreurs de permissions
- Fallback vers /tmp en cas de problème d'écriture
- Horodatage précis
- Identification du device dans les logs
- Fonction `print_log` pour combiner affichage console et logging

### 5. ftp_monitor.sh
Script de surveillance situé dans `${BASE_DIR}/ftp_monitor.sh`
- Exécution du script principal toutes les 15 secondes
- Utilisation du système de logging centralisé
- Redémarrage automatique au reboot via crontab
- Surveillance toutes les 5 minutes
- Redémarrage automatique si le processus n'est pas en cours d'exécution

### 6. cleanup.sh
Script de nettoyage automatique dans `${BASE_DIR}/cleanup.sh`
- Nettoyage du fichier d'état des envois
- Nettoyage du dossier temporaire
- Gestion de la rotation des logs (compression après 1 jour)
- Suppression des logs de plus de 30 jours
- Nettoyage récursif des fichiers .mkv sur le FTP
- Suppression des dossiers vides sur le FTP

## Prérequis
```bash
# Installation des dépendances nécessaires
sudo apt update
sudo apt install lftp curl
```

## Déploiement

1. **Création des dossiers** :
```bash
sudo mkdir -p /etc/telegram/ftp_video
sudo mkdir -p /usr/local/bin/ftp_video
sudo mkdir -p /var/tmp/FTP_TEMP
sudo mkdir -p /var/log/ftp_telegram
```

2. **Configuration des permissions** :
```bash
sudo chown -R $USER:$USER /usr/local/bin/ftp_video
sudo chown -R $USER:$USER /var/log/ftp_telegram
sudo chmod 755 /var/log/ftp_telegram
sudo touch /var/log/ftp_telegram/ftp_telegram.log
sudo chown $USER:$USER /var/log/ftp_telegram/ftp_telegram.log
sudo chmod 664 /var/log/ftp_telegram/ftp_telegram.log
```

3. **Création des fichiers** :
```bash
sudo touch /etc/telegram/ftp_video/ftp_config.cfg
sudo touch /usr/local/bin/ftp_video/ftp_telegram.sh
sudo touch /usr/local/bin/ftp_video/telegram.functions.sh
sudo touch /usr/local/bin/ftp_video/cleanup.sh
sudo touch /usr/local/bin/ftp_video/ftp_monitor.sh
sudo touch /usr/local/bin/ftp_video/phips_logger.sh

sudo chmod +x /usr/local/bin/ftp_video/*.sh
sudo chmod 600 /etc/telegram/ftp_video/ftp_config.cfg
```

4. **Configuration CRON** :
```bash
# Éditer le crontab de l'utilisateur
crontab -e

# Ajouter les lignes suivantes :
@reboot /usr/local/bin/ftp_video/ftp_monitor.sh &
*/5 * * * * if ! pgrep -f "ftp_monitor.sh" > /dev/null; then /usr/local/bin/ftp_video/ftp_monitor.sh & fi
0 0 * * * /usr/local/bin/ftp_video/cleanup.sh
```

## Gestion du service

### Démarrage manuel
```bash
/usr/local/bin/ftp_video/ftp_monitor.sh > /dev/null 2>&1 &
```

### Arrêt du service
```bash
pkill -f "ftp_monitor.sh"
```

### Vérification du statut
```bash
ps aux | grep "ftp_monitor.sh"
```

## Structure des fichiers

```
/etc/telegram/ftp_video/
└── ftp_config.cfg

/usr/local/bin/ftp_video/
├── ftp_telegram.sh
├── telegram.functions.sh
├── cleanup.sh
├── ftp_monitor.sh
└── phips_logger.sh

/var/tmp/
├── FTP_TEMP/
└── FTP_FILES_SEEN.txt

/var/log/ftp_telegram/
├── ftp_telegram_YYYY-MM-DD.log
└── ftp_telegram_YYYY-MM-DD.log.gz
```

## Vérification et tests

### Test initial
```bash
# Test manuel du script
/usr/local/bin/ftp_video/ftp_telegram.sh

# Vérification des logs
tail -f /var/log/ftp_telegram/ftp_telegram_$(date +%Y-%m-%d).log
```

### Vérification de la connexion Telegram
```bash
source /usr/local/bin/ftp_video/telegram.functions.sh
validate_telegram_token && test_telegram_send
```

## Dépannage

### Problèmes courants

1. **Erreurs de permissions** :
```bash
# Vérifier les permissions des dossiers
ls -la /var/log/ftp_telegram
ls -la /usr/local/bin/ftp_video
ls -la /var/tmp/FTP_TEMP
```

2. **Erreurs de connexion FTP** :
```bash
# Vérifier la configuration FTP
lftp -u $FTP_USER,$FTP_PASS $FTP_HOST
```

3. **Erreurs Telegram** :
```bash
# Vérifier le token et le chat ID
curl -s "https://api.telegram.org/bot${TELEGRAM_BOT_TOKEN}/getMe"
```

### Logs et debugging
- Les logs sont disponibles dans `/var/log/ftp_telegram/`
- Utilisation de `print_log` pour le debugging
- Fallback des logs vers `/tmp` en cas d'erreur