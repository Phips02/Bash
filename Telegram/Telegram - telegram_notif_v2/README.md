# Système de notification Telegram pour connexions SSH et su
Version 3.4

## À propos
Ce système permet de recevoir des notifications Telegram lors des connexions SSH et des utilisations de la commande su.

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
├── telegram.config              # Configuration centralisée
└── backup/                      # Dossier des sauvegardes automatiques

/usr/local/bin/telegram/notif_connexion/
└── telegram.sh                  # Script principal

/etc/pam.d/su                   # Configuration PAM pour les notifications su
/etc/bash.bashrc                # Configuration système pour l'exécution automatique
```

## Mise à jour

Pour mettre à jour le système de notification, exécutez les commandes suivantes en tant que root :

```bash
su -c "
cd /tmp && \
rm -f update_telegram_notif.sh* && \
wget --no-cache --no-cookies --header 'Cache-Control: no-cache' https://raw.githubusercontent.com/Phips02/Bash/main/Telegram/Telegram%20-%20telegram_notif_v2/update_telegram_notif.sh && \
chmod +x update_telegram_notif.sh && \
./update_telegram_notif.sh
"
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
cp telegram.sh /usr/local/bin/telegram/notif_connexion/
chmod +x /usr/local/bin/telegram/notif_connexion/telegram.sh
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

# Supprimer la configuration dans bash.bashrc et PAM
sed -i '/telegram.sh/d' /etc/bash.bashrc
sed -i '/telegram.sh/d' /etc/pam.d/su

# Supprimer les fichiers et sauvegardes
rm -rf /etc/telegram/notif_connexion
rm -rf /usr/local/bin/telegram/notif_connexion

# Optionnel : Supprimer le groupe
groupdel telegramnotif
``` 