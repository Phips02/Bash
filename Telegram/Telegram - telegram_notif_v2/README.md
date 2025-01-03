# Système de notification Telegram pour connexions SSH

## Installation automatique

```bash
# Si sudo n'est pas installé, connectez-vous en root
su -

# Installation des dépendances et du script
apt update && apt install sudo curl wget jq git -y
wget https://raw.githubusercontent.com/Phips02/Bash/main/Telegram/Telegram%20-%20telegram_notif_v2/install_telegram_notif.sh
chmod +x install_telegram_notif.sh
sudo ./install_telegram_notif.sh
```

## Structure des dossiers
```
/etc/telegram/notif_connexion/
└── telegram.config              # Configuration centralisée

/usr/local/bin/telegram/notif_connexion/
├── telegram.functions.sh        # Fonctions Telegram
└── telegram.sh                  # Script principal

/etc/profile                     # Configuration système pour l'exécution automatique
```

## Mise à jour

```bash
# Télécharger le script de mise à jour
cd /tmp
wget https://raw.githubusercontent.com/Phips02/Bash/main/Telegram/Telegram%20-%20telegram_notif_v2/update_telegram_notif.sh
chmod +x update_telegram_notif.sh
sudo ./update_telegram_notif.sh
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
``` 