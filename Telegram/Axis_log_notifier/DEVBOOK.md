# 📚 DEVBOK - Axis Log Notifier

## 📋 Informations Projet
- **Nom du Projet**: Axis Log Notifier
- **Date de début**: 24 mars 2024
- **Version actuelle**: 1.0.0
- **Responsable**: [Votre nom]

## 🎯 Objectifs du Projet
- [ ] Surveillance des logs Axis
- [ ] Notification via Telegram
- [ ] Détection d'anomalies
- [ ] Reporting automatisé

## 🏗️ Architecture
### Structure du Projet

### Technologies Utilisées
- Shell Script (Bash)
- API Telegram
- Axis Camera API
- Outils de monitoring système

## 📝 Journal de Développement

### Sprint 1 - [Date actuelle]
#### 🎯 Objectifs
- [ ] Mise en place de la structure du projet
- [ ] Configuration de l'intégration Telegram
- [ ] Implémentation de la lecture des logs Axis

#### 📈 Progrès
| Date | Description | Status | Notes |
|------|-------------|--------|-------|
| [Date] | Initialisation du projet | ✅ | Structure de base créée |
| [Date] | Configuration Telegram | ⏳ | En cours |

#### 🚧 Problèmes Rencontrés
- **Problème**: [À documenter]
  - Solution: [À documenter]
  - Ressources: [À documenter]

## 🔍 Tests et Qualité
### Tests Unitaires
- Shellcheck pour la validation syntaxique
- Tests de connexion Telegram
- Validation des logs Axis

### Tests d'Intégration
- Test de bout en bout du flux de notification
- Validation des performances

## 🔐 Sécurité
### Points de Vigilance
- Stockage sécurisé des tokens Telegram
- Gestion des permissions des fichiers de log
- Validation des entrées
- Sanitization des données

## 📊 Métriques
### Performance
- Temps de réponse des notifications
- Utilisation des ressources système
- Fiabilité de la détection

## 📦 Déploiement
### Environnements
- Development: Local
- Production: [À définir]

### Procédures

## 📚 Ressources
### Documentation Externe
- [API Telegram](https://core.telegram.org/bots/api)
- [Documentation Axis](https://developer.axis.com/vapix/)

### Outils
- Bash 4.0+
- curl
- jq (pour le parsing JSON)
- systemd (pour le service)

## 📋 TODO
- [ ] Implémenter la connexion Telegram
- [ ] Créer les scripts de base
- [ ] Mettre en place la surveillance des logs
- [ ] Configurer les notifications
- [ ] Documenter l'installation

## 🤝 Contribution
### Standards de Code
- Utilisation de shellcheck
- Documentation des fonctions
- Tests unitaires requis
- Respect des conventions de nommage

## 📞 Support
- Contact principal: [Votre email]
- Procédure d'escalade: [À définir]

---
*Dernière mise à jour: [Date actuelle]*

## État du Projet
Date de début : 24 mars 2024
Statut : En cours

## Étapes du Projet

### 1. Configuration initiale ✓
- [x] Mise en place de l'environnement de base
- [x] Structure des dossiers du projet
- [x] Fichiers de base (config.cfg, logger.sh)
- [x] Configuration ESLint et Prettier

### 2. Système de Logging ✓
- [x] Création du système de logging centralisé
- [x] Niveaux de log (DEBUG, INFO, WARNING, ERROR, CRITICAL)
- [x] Rotation des logs
- [x] Tests unitaires du logger

### 3. Intégration Axis Camera ⏳
- [ ] Configuration de l'authentification Axis
- [ ] Récupération des logs système (/axis-cgi/admin/systemlog.cgi)
- [ ] Gestion du rapport serveur (/axis-cgi/serverreport.cgi)
- [ ] Gestion du timeout pour serverreport.cgi
- [ ] Parser des logs et rapports
- [ ] Tests de connexion

### 4. Intégration Telegram ⏳
- [x] Configuration du bot Telegram
- [x] Système de notification
- [ ] Format des notifications pour les logs système
- [ ] Format des notifications pour le rapport serveur
- [ ] Gestion des erreurs de communication
- [ ] Tests d'intégration

### 5. Optimisation et Performance
- [ ] Gestion asynchrone du serverreport.cgi
- [ ] Cache des données
- [ ] Gestion des timeouts
- [ ] Optimisation des requêtes

### 6. Déploiement et Maintenance
- [ ] Script d'installation automatisé
- [ ] Service systemd
- [ ] Documentation de déploiement
- [ ] Procédures de backup
- [ ] Monitoring des performances

### 7. Documentation et Tests
- [ ] Documentation utilisateur
- [ ] Documentation technique
- [ ] Tests de performance
- [ ] Tests de sécurité

## Problèmes Rencontrés
- **Problème**: Permissions des fichiers de log
  - Solution: Utilisation de umask et chmod explicite
  - Date: 24/03/2024

- **Problème**: Configuration Telegram sécurisée
  - Solution: Stockage des tokens dans un fichier séparé avec permissions restreintes
  - Date: 24/03/2024

- **Problème**: Temps de génération serverreport.cgi
  - Solution: Implémentation d'un système asynchrone avec timeout configurable
  - Date: 24/03/2024

## Notes de Version
### v0.1.0 (24/03/2024)
- Configuration initiale
- Système de logging de base
- Structure du projet

## Prochaines Étapes
- Implémenter la récupération des logs système Axis
- Gérer le temps de génération du serverreport
- Configurer le format des notifications Telegram pour chaque type de log
- Mettre en place la gestion asynchrone des requêtes

