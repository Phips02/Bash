# Système de notification Telegram pour connexions SSH

## Prérequis
```bash
# Installation des dépendances essentielles
apt update
apt install sudo curl wget jq git -y
```

## Installation automatique

### 1. Installation standard
```bash
# Si sudo n'est pas installé, connectez-vous en root
su -

# Installation des dépendances
apt update && apt install sudo curl wget jq git -y

# Téléchargement et installation
wget https://raw.githubusercontent.com/Phips02/Bash/main/Telegram/Telegram%20-%20telegram_notif_v2/install_telegram_notif.sh
chmod +x install_telegram_notif.sh
sudo ./install_telegram_notif.sh
```

### 2. Configuration des permissions
```bash
# Configuration des permissions des scripts
sudo chmod 755 /usr/local/bin/telegram/notif_connexion/telegram.sh
sudo chmod 755 /usr/local/bin/telegram/notif_connexion/telegram.functions.sh
sudo chown root:telegramnotif /usr/local/bin/telegram/notif_connexion/*.sh

# Configuration des permissions du fichier de configuration
sudo chmod 644 /etc/telegram/notif_connexion/telegram.config
sudo chown root:telegramnotif /etc/telegram/notif_connexion/telegram.config

# Ajout de l'utilisateur au groupe
sudo usermod -a -G telegramnotif $USER

# Recharger les groupes pour l'utilisateur courant
newgrp telegramnotif
```

### 3. Test de l'installation
```bash
# Tester le script
sudo /usr/local/bin/telegram/notif_connexion/telegram.sh
```

### Obtenir vos identifiants Telegram

1. **Token du Bot** :
   - Contactez [@BotFather](https://t.me/botfather) sur Telegram
   - Créez un nouveau bot avec la commande `/newbot`
   - Copiez le token fourni

2. **Chat ID** :
   - Contactez [@userinfobot](https://t.me/userinfobot)
   - Le bot vous enverra votre Chat ID
   - Pour un groupe, ajoutez le bot au groupe et utilisez [@RawDataBot](https://t.me/RawDataBot)

## Structure des dossiers
```
/etc/telegram/notif_connexion/
└── telegram.config              # Configuration centralisée

/usr/local/bin/telegram/notif_connexion/
├── telegram.functions.sh        # Fonctions Telegram
└── telegram.sh                  # Script principal

/etc/profile                     # Configuration système pour l'exécution automatique
```



## Mise à jour manuelle
```bash
cd /tmp
rm -rf Bash
git clone https://github.com/Phips02/Bash.git
cd Bash/Telegram/Telegram\ -\ telegram_notif_v2
sudo cp *.sh /usr/local/bin/telegram/notif_connexion/
sudo chmod +x /usr/local/bin/telegram/notif_connexion/*.sh
cd /tmp
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

## Désinstallation

Pour désinstaller complètement le système de notification :

```bash
# Supprimer la ligne dans /etc/profile
sudo sed -i '/telegram.sh/d' /etc/profile

# Supprimer les fichiers
sudo rm -rf /etc/telegram/notif_connexion
sudo rm -rf /usr/local/bin/telegram/notif_connexion

# Optionnel : Supprimer le groupe
sudo groupdel telegramnotif

# Optionnel : Supprimer l'utilisateur telegram
sudo userdel -r telegram
``` 