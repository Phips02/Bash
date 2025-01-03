# Système de notification Telegram pour connexions SSH

## Installation automatique

### 1. Installation en une ligne
```bash
# Installation avec TOKEN et CHAT_ID en arguments
wget -O - https://raw.githubusercontent.com/Phips02/Bash/main/Telegram%20-%20telegram_notif_v2/install_telegram_notif.sh | sudo bash -s -- "VOTRE_TOKEN" "VOTRE_CHAT_ID"
```

### 2. Installation manuelle du script d'installation
```bash
# Télécharger le script d'installation
wget https://raw.githubusercontent.com/Phips02/Bash/main/Telegram/telegram_notif_v2/install_telegram_notif.sh

# Rendre le script exécutable
chmod +x install_telegram_notif.sh

# Exécuter le script avec vos identifiants Telegram
sudo ./install_telegram_notif.sh "VOTRE_TOKEN" "VOTRE_CHAT_ID"
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

## Déploiement depuis GitHub

### 1. Préparation du système
```bash
# Installation des dépendances
apt update
apt install sudo curl jq git -y

# Création de l'utilisateur telegram
sudo useradd -m -s /bin/bash telegram

# Définir un mot de passe pour l'utilisateur telegram
sudo passwd telegram

# Ajouter l'utilisateur telegram au groupe sudo
sudo usermod -aG sudo telegram

# Création du groupe telegramnotif et ajout des utilisateurs
sudo groupadd telegramnotif
sudo usermod -a -G telegramnotif telegram
sudo usermod -a -G telegramnotif $USER  # Ajoute aussi l'utilisateur courant
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
cd Bash/Telegram/telegram_notif_v2

# Créer les dossiers nécessaires
sudo mkdir -p /etc/telegram/notif_connexion
sudo mkdir -p /usr/local/bin/telegram/notif_connexion

# Copier les fichiers
sudo cp deploy_telegram.sh /usr/local/bin/telegram/notif_connexion/
```

### 4. Configuration des permissions et sécurité
```bash
# --- Permissions des répertoires principaux ---
# Répertoire des binaires : lecture et exécution pour le groupe
sudo chmod 750 /usr/local/bin/telegram/notif_connexion
sudo chown -R root:telegramnotif /usr/local/bin/telegram/notif_connexion

# Configuration : lecture seule pour le groupe
sudo chmod 640 /etc/telegram/notif_connexion/telegram.config
sudo chown root:telegramnotif /etc/telegram/notif_connexion/telegram.config

# Scripts : exécutables uniquement par root et le groupe
sudo chmod 750 /usr/local/bin/telegram/notif_connexion/*.sh
sudo chown root:telegramnotif /usr/local/bin/telegram/notif_connexion/*.sh

# --- Vérification des permissions ---
ls -la /usr/local/bin/telegram/notif_connexion
ls -la /etc/telegram/notif_connexion
```

### 5. Déploiement initial
```bash
# Exécuter le script de déploiement
cd /usr/local/bin/telegram/notif_connexion
sudo ./deploy_telegram.sh
```

### 6. Vérification du déploiement
```bash
# Vérifier que les fichiers ont été créés
ls -la /etc/telegram/notif_connexion
ls -la /usr/local/bin/telegram/notif_connexion

# Vérifier que le script est bien dans /etc/profile
grep "telegram.sh" /etc/profile
```

### 7. Test du système
```bash
# Se déconnecter et se reconnecter pour tester
exit
ssh user@votre_serveur
```

## Commandes utiles

### Test manuel
```bash
# Exécuter le script manuellement
/usr/local/bin/telegram/notif_connexion/telegram.sh
```

### Désactivation temporaire
```bash
# Commenter la ligne dans /etc/profile
sudo sed -i 's/^\/usr\/local\/bin\/telegram\/notif_connexion\/telegram.sh/#&/' /etc/profile
```

### Réactivation
```bash
# Décommenter la ligne dans /etc/profile
sudo sed -i 's/^#\/usr\/local\/bin\/telegram\/notif_connexion\/telegram.sh/\/usr\/local\/bin\/telegram\/notif_connexion\/telegram.sh/' /etc/profile
```

## Mise à jour manuelle
```bash
cd /tmp
rm -rf Bash
git clone https://github.com/Phips02/Bash.git
cd Bash/Telegram/telegram_notif_v2
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