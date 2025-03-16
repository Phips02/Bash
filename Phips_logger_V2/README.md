# Phips Logger V2

Un système de logging universel en Bash pour vos scripts et applications.

## Installation

### Installation automatique

Utilisez le script de déploiement pour une installation rapide et complète :


# Télécharger le script de déploiement
```bash
sudo curl -O https://raw.githubusercontent.com/Phips02/Bash/main/Phips_logger_V2/deploy.sh
```

# Rendre le script exécutable
```bash
sudo chmod +x deploy.sh
```

# Exécuter le script d'installation
```bash
sudo ./deploy.sh
```

### Installation manuelle

Si vous préférez installer manuellement :

1. Créez les répertoires nécessaires :
```bash
sudo mkdir -p /usr/local/bin/phips_logger
sudo mkdir -p /etc/phips_logger
sudo mkdir -p /var/log/phips_logger
```

2. Téléchargez les fichiers :
```bash
sudo curl -o /usr/local/bin/phips_logger/universal_logger.sh https://raw.githubusercontent.com/Phips02/Bash/main/Phips_logger_V2/universal_logger.sh
sudo curl -o /etc/phips_logger/logger_config.cfg https://raw.githubusercontent.com/Phips02/Bash/main/Phips_logger_V2/logger_config.cfg
```

3. Configurez les permissions :
```bash
sudo chmod +x /usr/local/bin/phips_logger/universal_logger.sh
sudo chmod 644 /etc/phips_logger/logger_config.cfg
sudo chmod 775 /var/log/phips_logger
```

## Utilisation

### Dans vos scripts

Pour utiliser le logger dans vos scripts :

```bash
#!/bin/bash

# Importer le logger
LOGGER_PATH="/usr/local/bin/phips_logger/universal_logger.sh"
if [ -f "$LOGGER_PATH" ]; then
    source "$LOGGER_PATH"
else
    echo "Logger non trouvé: $LOGGER_PATH"
    exit 1
fi

# Exemples d'utilisation
print_log "INFO" "mon_script" "Démarrage du script"
print_log "DEBUG" "mon_script" "Variable: $var"
print_log "WARNING" "mon_script" "Attention: quota presque atteint"
print_log "ERROR" "mon_script" "Erreur lors de l'exécution"
print_log "CRITICAL" "mon_script" "Erreur critique, arrêt du programme"
```

### Options disponibles

Le logger offre plusieurs niveaux de logs :
- DEBUG - Informations de débogage détaillées
- INFO - Informations générales sur le déroulement du script
- WARNING - Avertissements qui ne bloquent pas l'exécution
- ERROR - Erreurs qui peuvent impacter le fonctionnement
- CRITICAL - Erreurs critiques qui nécessitent une intervention

### Commandes directes

Si vous avez créé le lien symbolique lors de l'installation :

```bash
# Tester le logger
phips-logger test

# Effectuer une rotation des logs (supprimer les logs de plus de X jours)
phips-logger rotate 7

# Afficher l'aide
phips-logger help
```

## Configuration

Le fichier de configuration se trouve dans `/etc/phips_logger/logger_config.cfg`. Vous pouvez modifier ce fichier pour adapter le comportement du logger à vos besoins.

### Options de configuration

```bash
# Configuration générale
LOG_DIR="/var/log/phips_logger"      # Répertoire où stocker les logs
LOG_PREFIX="phips"                   # Préfixe pour les fichiers de logs
LOG_LEVEL="INFO"                     # Niveau de log (DEBUG, INFO, WARNING, ERROR, CRITICAL)
USE_SYSLOG="false"                   # Intégration avec syslog

# Configuration des notifications Telegram
ENABLE_NOTIFICATIONS="false"         # Activer/désactiver les notifications Telegram
NOTIFICATION_LEVEL="WARNING"         # Niveau minimum pour envoyer des notifications
TELEGRAM_BOT_TOKEN=""                # Token de votre bot Telegram
TELEGRAM_CHAT_ID=""                  # ID du chat/groupe où envoyer les notifications
```

## Fonctionnalités

- Logs avec niveaux (DEBUG, INFO, WARNING, ERROR, CRITICAL)
- Rotation automatique des logs
- Intégration avec syslog
- Notifications Telegram pour les erreurs
- Messages colorés dans le terminal
- Fallback automatique si le répertoire de logs n'est pas accessible

## Dépannage

Si vous rencontrez des problèmes avec le logger :

1. Vérifiez les permissions des répertoires :
```bash
ls -la /usr/local/bin/phips_logger
ls -la /etc/phips_logger
ls -la /var/log/phips_logger
```

2. Testez le logger directement :
```bash
sudo /usr/local/bin/phips_logger/universal_logger.sh test
```

3. Vérifiez les logs générés :
```bash
cat /var/log/phips_logger/phips_*.log
```

4. Si les logs ne sont pas créés dans le répertoire principal, vérifiez dans le répertoire de fallback :
```bash
cat /tmp/phips_*.log
```