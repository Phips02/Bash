# Système de notification Telegram pour connexions SSH

## Installation automatique

```bash
# Se connecter en root
su -

# Installation des dépendances et du script
apt update && apt install curl wget jq git -y
wget https://raw.githubusercontent.com/Phips02/Bash/main/Telegram/Telegram%20-%20telegram_notif_v2/install_telegram_notif.sh
chmod +x install_telegram_notif.sh
./install_telegram_notif.sh
```

## Structure des dossiers
```
/etc/telegram/notif_connexion/
└── telegram.config              # Configuration centralisée

/usr/local/bin/telegram/notif_connexion/
├── telegram.functions.sh        # Fonctions Telegram
└── telegram.sh                  # Script principal

/etc/bash.bashrc                 # Configuration système pour l'exécution automatique
```

## Mise à jour

```bash
# Se connecter en root
su -

# Télécharger le script de mise à jour
cd /tmp
wget https://raw.githubusercontent.com/Phips02/Bash/main/Telegram/Telegram%20-%20telegram_notif_v2/update_telegram_notif.sh
chmod +x update_telegram_notif.sh
./update_telegram_notif.sh
```

## Mise à jour manuelle
```bash
# Se connecter en root
su -

# Télécharger le script de mise à jour
cd /tmp
rm -rf Bash
git clone https://github.com/Phips02/Bash.git
cd Bash/Telegram/Telegram\ -\ telegram_notif_v2
cp *.sh /usr/local/bin/telegram/notif_connexion/
chmod +x /usr/local/bin/telegram/notif_connexion/*.sh
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

Pour désinstaller complètement le système de notification (en tant que root) :

```bash
# Se connecter en root
su -

# Supprimer la ligne dans /etc/bash.bashrc
sed -i '/telegram.sh/d' /etc/bash.bashrc

# Supprimer les fichiers
rm -rf /etc/telegram/notif_connexion
rm -rf /usr/local/bin/telegram/notif_connexion

# Optionnel : Supprimer le groupe
groupdel telegramnotif
``` 