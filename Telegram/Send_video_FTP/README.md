#Phips
#Version : 2024.12.22 15:05


# Système d'envoi automatique de vidéos FTP vers Telegram

## Description
Ce système permet de récupérer automatiquement des fichiers vidéo (.mkv) depuis un serveur FTP et de les envoyer vers un groupe Telegram. Le système parcourt récursivement les sous-dossiers du FTP pour traiter tous les fichiers vidéo.

## Description des scripts

### 1. ftp_config.cfg
Fichier de configuration situé dans `/etc/telegram/ftp_video/ftp_config.cfg`
- Configuration du serveur FTP (host, port, credentials)
- Configuration Telegram (bot token, chat ID)
- Configuration du logger (chemin et fichier de log)

### 2. ftp_telegram.sh
Script principal situé dans `/usr/local/bin/ftp_video/ftp_telegram.sh`
- Vérification complète de la configuration et des dépendances
- Gestion des erreurs améliorée
- Traitement récursif des dossiers FTP avec exclusion des dossiers système (@eaDir, @tmp)
- Système de retry pour l'envoi Telegram (3 tentatives)
- Gestion des descriptions avec nom du dossier source et nom du fichier
- Nettoyage automatique des fichiers temporaires

### 3. telegram.functions.sh
Bibliothèque de fonctions Telegram dans `/usr/local/bin/ftp_video/telegram.functions.sh`
- Validation du token Telegram
- Gestion des messages Telegram
- Gestion des erreurs de communication

### 4. cleanup.sh
Script de nettoyage automatique dans `/usr/local/bin/ftp_video/cleanup.sh`
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
# Définir les permissions des dossiers
sudo chown -R $USER:$USER /usr/local/bin/ftp_video
sudo chown -R $USER:$USER /var/log/ftp_telegram
sudo chmod 755 /var/log/ftp_telegram

# Créer le fichier de log
sudo touch /var/log/ftp_telegram/ftp_telegram.log
sudo chown $USER:$USER /var/log/ftp_telegram/ftp_telegram.log
sudo chmod 664 /var/log/ftp_telegram/ftp_telegram.log
```

3. **Création des fichiers** :
```bash
# Création des fichiers de configuration et des scripts
sudo touch /etc/telegram/ftp_video/ftp_config.cfg
sudo touch /usr/local/bin/ftp_video/ftp_telegram.sh
sudo touch /usr/local/bin/ftp_video/telegram.functions.sh
sudo touch /usr/local/bin/ftp_video/cleanup.sh
sudo touch /usr/local/bin/phips_logger.sh

# Rendre les scripts exécutables
sudo chmod +x /usr/local/bin/ftp_video/*.sh
sudo chmod +x /usr/local/bin/phips_logger.sh

# Définir les bonnes permissions pour le fichier de configuration
sudo chmod 600 /etc/telegram/ftp_video/ftp_config.cfg
```

4. **Édition des fichiers** :
```bash
# Éditer les fichiers avec votre éditeur préféré (exemple avec nano)
sudo nano /etc/telegram/ftp_video/ftp_config.cfg
sudo nano /usr/local/bin/ftp_video/ftp_telegram.sh
sudo nano /usr/local/bin/ftp_video/telegram.functions.sh
sudo nano /usr/local/bin/ftp_video/cleanup.sh
sudo nano /usr/local/bin/phips_logger.sh
```

5. **Configuration CRON** :
```bash
# Éditer le crontab de l'utilisateur (PAS root)
crontab -e

# Ajouter les lignes suivantes :
# Pour l'exécution du script principal toutes les minutes
* * * * * /usr/local/bin/ftp_video/ftp_telegram.sh

# Pour le nettoyage quotidien à minuit
0 0 * * * /usr/local/bin/ftp_video/cleanup.sh

# Vérifier que le crontab est bien configuré
crontab -l
```

## Fichiers et dossiers importants

```
/etc/telegram/ftp_video/
└── ftp_config.cfg

/usr/local/bin/ftp_video/
├── ftp_telegram.sh
├── telegram.functions.sh
├── cleanup.sh
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
# Test de la connexion Telegram via les fonctions
source /usr/local/bin/ftp_video/telegram.functions.sh
validate_telegram_token && test_telegram_send
```

### Vérification des fichiers
```bash
# Vérification des fichiers temporaires
ls -l /var/tmp/FTP_TEMP

# Historique des envois
cat /var/tmp/FTP_FILES_SEEN.txt
```

## Dépannage

### Problèmes courants

1. **Erreurs de permissions** :
```bash
# Vérifier les permissions des dossiers et fichiers
ls -la /var/log/ftp_telegram
ls -la /usr/local/bin/ftp_video

# Corriger les permissions si nécessaire
sudo chown -R $USER:$USER /var/log/ftp_telegram/
sudo chmod -R 755 /var/log/ftp_telegram/
sudo chmod 664 /var/log/ftp_telegram/ftp_telegram.log
```

2. **Problèmes avec CRON** :
```bash
# Vérifier que le crontab est configuré pour le bon utilisateur
crontab -l

# Vérifier les logs de cron
sudo tail -f /var/log/syslog | grep CRON
```

3. **Erreurs FTP** :
- Vérifier les paramètres dans ftp_config.cfg
- Utiliser test_ftp.sh pour diagnostiquer
- Vérifier les permissions des dossiers

4. **Erreurs Telegram** :
- Vérifier le token et le chat ID
- Consulter les logs pour les messages d'erreur
- Vérifier la connexion internet

5. **Problèmes de fichiers** :
- Vérifier les permissions des dossiers
- S'assurer que les fichiers .mkv sont lisibles
- Vérifier l'espace disque disponible

## Gestion des logs

### Rotation automatique des logs
- Les logs sont compressés après 1 jour
- Conservation pendant 30 jours (configurable via MAX_LOG_DAYS dans cleanup.sh)
- Nettoyage automatique via cleanup.sh

### Nettoyage automatique
Le script `cleanup.sh` effectue :
- Nettoyage du fichier d'état (`FTP_FILES_SEEN.txt`)
- Nettoyage du dossier temporaire (`FTP_TEMP`)
- Compression des logs d'hier
- Suppression des logs de plus de 30 jours
- Nettoyage complet des fichiers .mkv sur le FTP

### Consultation des logs
```bash
# Voir le log du jour
tail -f /var/log/ftp_telegram/ftp_telegram_$(date +%Y-%m-%d).log

# Voir un log compressé spécifique
zcat /var/log/ftp_telegram/ftp_telegram_2024-03-20.log.gz

# Lister tous les fichiers de log
ls -l /var/log/ftp_telegram/
```
