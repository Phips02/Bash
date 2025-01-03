# Axis Log Notifier - Template de Gestion des Logs pour Scripts Bash

## Description
Ce template fournit une solution complète pour la surveillance des logs Axis et leur notification via Telegram. Il inclut :
- Un système de logging centralisé avec niveaux de log
- Une intégration avec l'API Telegram pour les notifications
- Une surveillance des logs Axis Camera
- Une gestion de configuration flexible
- Des fonctions utilitaires communes
- Un script d'installation automatisé
- Une structure de projet réutilisable

## Technologies Utilisées
- Shell Script (Bash 4.0+)
- API Telegram
- Axis Camera API
- curl (pour les requêtes HTTP)
- jq (pour le parsing JSON)
- systemd (pour le service)

## Structure des fichiers
```
/etc/<MonProjet>/
└── config.cfg              # Configuration centralisée

/usr/local/bin/<MonProjet>/
├── phips_logger.sh        # Système de logging
├── common.sh             # Fonctions communes
├── script.sh             # Script template
└── install.sh            # Script d'installation

/var/log/<MonProjet>/      # Dossier des logs
└── <MonProjet>_YYYY-MM-DD.log

/tmp/<MonProjet>/          # Dossier temporaire
└── temp_files            # Fichiers temporaires
```

## Installation

### Prérequis
- Bash 4.0 ou supérieur
- curl
- jq
- Accès root pour l'installation

### Méthode automatique (recommandée)
```bash
# Donner les droits d'exécution
chmod +x install.sh

# Lancer l'installation (remplacer MonProjet par le nom de votre projet)
sudo ./install.sh MonProjet
```

### Méthode manuelle
1. Créer les dossiers nécessaires :
```bash
sudo mkdir -p /etc/<MonProjet>
sudo mkdir -p /usr/local/bin/<MonProjet>
sudo mkdir -p /var/log/<MonProjet>
sudo mkdir -p /tmp/<MonProjet>
```

2. Copier les fichiers :
```bash
sudo cp config.cfg /etc/<MonProjet>/
sudo cp phips_logger.sh common.sh /usr/local/bin/<MonProjet>/
```

3. Configurer les permissions :
```bash
sudo chmod 755 /usr/local/bin/<MonProjet>
sudo chmod 775 /var/log/<MonProjet>
sudo chmod 640 /etc/<MonProjet>/config.cfg
sudo chmod 750 /usr/local/bin/<MonProjet>/*.sh
```

## Configuration
Le fichier `config.cfg` contient toutes les configurations :

```bash
# Configuration du projet
PROJECT_NAME="MonProjet"
PROJECT_LOG_NAME="NomDeMonProjet"

# Configuration des logs
LOG_LEVEL="INFO"              # DEBUG, INFO, WARNING, ERROR, CRITICAL
LOG_RETENTION_DAYS=30         # Conservation des logs
LOG_PERMISSIONS="664"         # Permissions des fichiers

# Configuration Telegram
TELEGRAM_BOT_TOKEN=""         # Token du bot Telegram
TELEGRAM_CHAT_ID=""          # ID du chat pour les notifications
ENABLE_NOTIFICATIONS=false    # Activer/désactiver les notifications
NOTIFICATION_LEVEL="ERROR"    # Niveau minimum pour les notifications

# Configuration des timeouts et retry
OPERATION_TIMEOUT=30          # Timeout en secondes
MAX_RETRIES=3                # Nombre maximum de tentatives
```

## Sécurité
- Les tokens Telegram doivent être stockés de manière sécurisée
- Permissions restrictives sur config.cfg (640)
- Validation des entrées et sanitization des données
- Logs protégés en écriture (664)
- Exécution avec les privilèges minimaux nécessaires

## Utilisation

### 1. Dans vos scripts
```bash
#!/bin/bash

# Charger la configuration
CONFIG_FILE="/etc/${PROJECT_NAME:-MonProjet}/config.cfg"
source "$CONFIG_FILE"
source "$LOGGER_PATH"

# Vérifier le logger
if ! declare -f print_log >/dev/null; then
    echo "ERREUR: Logger non chargé correctement"
    exit 1
fi

# Utiliser le logger
print_log "INFO" "monscript" "Message à logger"
```

### 2. Fonctions communes disponibles
```bash
# Vérifier une commande
check_command "ma_commande"

# Vérifier plusieurs dépendances
check_dependencies "git" "curl" "wget"

# Vérifier les privilèges root
if ! is_root; then
    print_log "ERROR" "script" "Nécessite les privilèges root"
    exit 1
fi
```

## Tests
### Tests Unitaires
- Validation syntaxique avec shellcheck
- Tests de connexion Telegram
- Validation des logs Axis
- Vérification des permissions

### Tests d'Intégration
- Test du flux complet de notification
- Validation des performances
- Tests de charge

## Niveaux de Log et Notifications
### Niveaux disponibles
- `DEBUG`    : Messages de débogage détaillés
- `INFO`     : Informations générales
- `WARNING`  : Avertissements
- `ERROR`    : Erreurs
- `CRITICAL` : Erreurs critiques

### Format des Logs
```
YYYY-MM-DD HH:MM:SS [LEVEL] [COMPONENT] [HOSTNAME] Message
```

### Notifications Telegram
- Envoi automatique selon NOTIFICATION_LEVEL
- Format structuré avec nom du projet et hostname
- Support du Markdown pour le formatage

## Maintenance
- Rotation automatique des logs après LOG_RETENTION_DAYS jours
- Nettoyage automatique du dossier temporaire
- Vérification périodique des permissions
- Monitoring des ressources système

## Support et Contribution
- Utilisation obligatoire de shellcheck
- Documentation requise pour les nouvelles fonctionnalités
- Tests unitaires pour chaque modification
- Respect des conventions de nommage

## Version
- Version : 2024.03.24
- Auteur : Phips

## Licence
Ce projet est sous licence libre.
