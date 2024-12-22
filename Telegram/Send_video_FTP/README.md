#Phips
#Version : 2024.12.22 13:41


# Système d'envoi automatique de vidéos FTP vers Telegram

## Prérequis
```bash
# Installation des dépendances nécessaires
sudo apt update
sudo apt install lftp curl
```

## Description
Ce système permet de récupérer automatiquement des fichiers vidéo (.mkv) depuis un serveur FTP et de les envoyer vers un groupe Telegram. Il est composé de trois fichiers principaux qui travaillent ensemble pour assurer cette fonction.

## Description des scripts

### 1. ftp_config.cfg
`ftp_config.cfg` pour configurer les paramètres de connexion
- Les accès FTP (serveur, identifiants)
- Les accès Telegram (token, chat ID)
- Les chemins des dossiers

### 2. ftp_telegram.sh
`ftp_telegram.sh` pour télécharger et envoyer les vidéos vers Telegram
- Télécharge les vidéos depuis le FTP
- Les envoie vers Telegram
- Garde une trace des envois

### 3. telegram.functions.sh
`telegram.functions.sh` pour gérer les communications avec Telegram
- Gère la communication avec Telegram
- Vérifie les paramètres

## Déploiement rapide

1. **Créer les dossiers nécessaires** :
```bash
sudo mkdir -p /etc/telegram/ftp_video
sudo mkdir -p /usr/local/bin/ftp_video
sudo mkdir -p /var/tmp/FTP_TEMP
```

2. **Copier les fichiers** :
```bash
sudo cp ftp_config.cfg /etc/telegram/ftp_video/
sudo cp ftp_telegram.sh /usr/local/bin/ftp_video/
sudo cp telegram.functions.sh /usr/local/bin/ftp_video/
```

3. **Configurer les permissions** :
```bash
sudo chmod +x /usr/local/bin/ftp_video/ftp_telegram.sh
sudo chmod +x /usr/local/bin/ftp_video/telegram.functions.sh
sudo chmod 600 /etc/telegram/ftp_video/ftp_config.cfg
```

4. **Configurer ftp_config.cfg** :
```bash
sudo nano /etc/telegram/ftp_video/ftp_config.cfg
# Modifier les paramètres selon votre configuration
```

5. **Configurer la tâche CRON** :
```bash
sudo crontab -e
# Ajouter la ligne :
* * * * * /usr/local/bin/ftp_video/ftp_telegram.sh >> /var/log/ftp_telegram.log 2>&1
```

## Structure des fichiers

/etc/telegram/ftp_video/
└── ftp_config.cfg

/usr/local/bin/ftp_video/
├── ftp_telegram.sh
└── telegram.functions.sh

## Test et vérification

### Test initial
```bash
# Tester le script manuellement
sudo /usr/local/bin/ftp_video/ftp_telegram.sh

# Vérifier les logs
tail -f /var/log/ftp_telegram.log
```

### Vérification des fichiers
```bash
# Vérifier les fichiers temporaires
ls -l /var/tmp/FTP_TEMP

# Vérifier l'historique des fichiers envoyés
cat /var/tmp/FTP_FILES_SEEN.txt
```

### Test de la connexion FTP
```bash
# Tester le script de vérification FTP
sudo /usr/local/bin/ftp_video/test_ftp.sh
```

## Dépannage

### Problèmes courants
1. **Erreur de connexion FTP** :
```bash
# Tester la connexion FTP avec lftp
lftp -u username,password ftp://your_host:port
# Dans lftp, vous pouvez utiliser ces commandes :
# ls        # Liste les fichiers
# pwd       # Affiche le répertoire courant
# exit      # Quitte lftp
```

2. **Erreur Telegram** :
```bash
# Tester l'API Telegram
curl -s "https://api.telegram.org/botYOUR_BOT_TOKEN/getMe"
```

3. **Problèmes de permissions** :
```bash
# Vérifier les permissions
ls -l /usr/local/bin/ftp_video/
ls -l /etc/telegram/ftp_video/
```

## Fichiers importants
- Configuration : `/etc/telegram/ftp_video/ftp_config.cfg`
- Scripts : `/usr/local/bin/ftp_video/`
- Fichiers temporaires : `/var/tmp/FTP_TEMP`
- État des fichiers : `/var/tmp/FTP_FILES_SEEN.txt`
- Logs : `/var/log/ftp_telegram.log`
