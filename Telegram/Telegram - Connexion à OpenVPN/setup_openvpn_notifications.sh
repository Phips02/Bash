#!/bin/bash

# Variables
SCRIPTS_DIR="/usr/local/bin"
SERVER_CONF="/etc/openvpn/server.conf"
CREDENTIALS_FILE="/etc/openvpn/telegram_credentials"

# Fonction pour envoyer une notification de test
send_test_notification() {
  local MESSAGE="$1"
  local BOT_TOKEN=$(grep BOT_TOKEN $CREDENTIALS_FILE | cut -d'=' -f2)
  local CHAT_ID=$(grep CHAT_ID $CREDENTIALS_FILE | cut -d'=' -f2)
  curl -s -X POST "https://api.telegram.org/bot$BOT_TOKEN/sendMessage" -d chat_id=$CHAT_ID -d text="$MESSAGE"
}

# Demande des informations à l'utilisateur
read -p "Entrez le token du bot Telegram : " BOT_TOKEN
read -p "Entrez l'ID du chat Telegram : " CHAT_ID
read -p "Entrez le nom du service : " SERVICE_NAME

# Stocker les crédentials dans un fichier sécurisé
echo "BOT_TOKEN=$BOT_TOKEN" > $CREDENTIALS_FILE
echo "CHAT_ID=$CHAT_ID" >> $CREDENTIALS_FILE
echo "SERVICE_NAME=$SERVICE_NAME" >> $CREDENTIALS_FILE

# Modifier les permissions pour que seul le propriétaire puisse lire et écrire
chmod 600 $CREDENTIALS_FILE

# Vérifier et créer le répertoire des scripts si nécessaire
if [[ ! -d $SCRIPTS_DIR ]]; then
  mkdir -p $SCRIPTS_DIR
  echo "Répertoire $SCRIPTS_DIR créé."
else
  echo "Répertoire $SCRIPTS_DIR déjà existant."
fi

# Supprimer les anciens scripts s'ils existent
if [[ -f $SCRIPTS_DIR/notify_connect.sh ]]; then
  rm -f $SCRIPTS_DIR/notify_connect.sh
  echo "Ancien script de notification de connexion supprimé."
fi

if [[ -f $SCRIPTS_DIR/notify_disconnect.sh ]]; then
  rm -f $SCRIPTS_DIR/notify_disconnect.sh
  echo "Ancien script de notification de déconnexion supprimé."
fi

# Script de notification de connexion
cat <<EOF > $SCRIPTS_DIR/notify_connect.sh
#!/bin/bash

# Charger les crédentials Telegram
source $CREDENTIALS_FILE

DATE=\$(date "+%F %H:%M:%S")
UTILISATEUR=\$common_name
IP_PUBLIC=\$trusted_ip

if [[ -z "\$UTILISATEUR" || -z "\$IP_PUBLIC" ]]; then
  echo "Erreur : UTILISATEUR ou IP_PUBLIC n'est pas défini."
  exit 1
fi

MESSAGE="\$DATE %0A\
OpenVPN \$SERVICE_NAME %0A\
Utilisateur connecté : \$UTILISATEUR %0A\
Public IP : \$IP_PUBLIC %0A"

# Envoyer une notification via l'API Telegram
curl -s -X POST "https://api.telegram.org/bot\$BOT_TOKEN/sendMessage" -d chat_id=\$CHAT_ID -d text="\$MESSAGE"
EOF

# Script de notification de déconnexion
cat <<EOF > $SCRIPTS_DIR/notify_disconnect.sh
#!/bin/bash

# Charger les crédentials Telegram
source $CREDENTIALS_FILE

DATE=\$(date "+%F %H:%M:%S")
UTILISATEUR=\$common_name
temps_en_secondes=\$time_duration

if [[ -z "\$UTILISATEUR" || -z "\$temps_en_secondes" ]]; then
  echo "Erreur : UTILISATEUR ou temps_en_secondes n'est pas défini."
  exit 1
fi

# Calcul des heures, des minutes et des secondes
heures=\$((temps_en_secondes / 3600))
minutes=\$(( (temps_en_secondes % 3600) / 60 ))
secondes=\$((temps_en_secondes % 60))

# Ajout de zéros de remplissage si nécessaire
heures=\$(printf "%02d" \$heures)
minutes=\$(printf "%02d" \$minutes)
secondes=\$(printf "%02d" \$secondes)

MESSAGE="\$DATE %0A\
OpenVPN \$SERVICE_NAME %0A\
Utilisateur déconnecté : \$UTILISATEUR %0A\
Durée de la connexion : \\\`\$heures:\$minutes:\$secondes\\\` %0A"

# Envoyer une notification via l'API Telegram
curl -s -X POST "https://api.telegram.org/bot\$BOT_TOKEN/sendMessage" -d chat_id=\$CHAT_ID -d text="\$MESSAGE" -d parse_mode="Markdown"
EOF

# Rendre les scripts exécutables
chmod +x $SCRIPTS_DIR/notify_connect.sh
chmod +x $SCRIPTS_DIR/notify_disconnect.sh

# Vérifier l'existence et les permissions des scripts
if [[ -f $SCRIPTS_DIR/notify_connect.sh && -x $SCRIPTS_DIR/notify_connect.sh ]]; then
  echo "Le script de notification de connexion existe et est exécutable."
  send_test_notification "Test de connexion : Le script de notification de connexion est exécutable."
else
  echo "Erreur : Le script de notification de connexion n'existe pas ou n'est pas exécutable."
  exit 1
fi

if [[ -f $SCRIPTS_DIR/notify_disconnect.sh && -x $SCRIPTS_DIR/notify_disconnect.sh ]]; then
  echo "Le script de notification de déconnexion existe et est exécutable."
  send_test_notification "Test de déconnexion : Le script de notification de déconnexion est exécutable."
else
  echo "Erreur : Le script de notification de déconnexion n'existe pas ou n'est pas exécutable."
  exit 1
fi

# Ajouter script-security 2 si non présent
if ! grep -q "^script-security 2" $SERVER_CONF; then
  echo "script-security 2" >> $SERVER_CONF
  echo "Ajout de 'script-security 2' dans la configuration OpenVPN."
else
  echo "'script-security 2' est déjà présent dans la configuration OpenVPN."
fi

# Ajouter les hooks dans le fichier de configuration OpenVPN
if ! grep -q "client-connect $SCRIPTS_DIR/notify_connect.sh" $SERVER_CONF; then
  echo "client-connect $SCRIPTS_DIR/notify_connect.sh" >> $SERVER_CONF
  echo "Ajout du hook 'client-connect' dans la configuration OpenVPN."
else
  echo "Le hook 'client-connect' est déjà présent dans la configuration OpenVPN."
fi

if ! grep -q "client-disconnect $SCRIPTS_DIR/notify_disconnect.sh" $SERVER_CONF; then
  echo "client-disconnect $SCRIPTS_DIR/notify_disconnect.sh" >> $SERVER_CONF
  echo "Ajout du hook 'client-disconnect' dans la configuration OpenVPN."
else
  echo "Le hook 'client-disconnect' est déjà présent dans la configuration OpenVPN."
fi

# Redémarrer le service OpenVPN pour appliquer les changements
systemctl restart openvpn@server

if [[ $? -eq 0 ]]; then
  echo "Redémarrage du service OpenVPN réussi."
  echo "Configuration des scripts de notification pour $SERVICE_NAME terminée avec succès."
  send_test_notification "Configuration des scripts de notification pour $SERVICE_NAME terminée avec succès."
else
  echo "Erreur lors du redémarrage du service OpenVPN."
  send_test_notification "Erreur lors du redémarrage du service OpenVPN."
fi
