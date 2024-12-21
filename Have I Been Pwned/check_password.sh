#!/usr/bin/env bash

#Phips
#Version : 2024.12.21 09:35
#Script original : https://github.com/yrougy/CheckPasswordLeak

# URL de l'API
URL="https://api.pwnedpasswords.com/range/"
HASH="sha1sum"

# Fonction principale pour vérifier le mot de passe
check_password() {
    local PASS="$1"

    # Calcul du hash SHA-1 et conversion en majuscules
    local SHA1PASS=$(echo -n "$PASS" | $HASH | awk '{print toupper($1)}')
    local HEADSHA="${SHA1PASS:0:5}"
    local TAILSHA="${SHA1PASS:5}"

    # Requête à l'API
    local RESPONSE=$(curl -s "${URL}${HEADSHA}" 2>/dev/null)
    if [[ $? -ne 0 ]]; then
        echo "Erreur : Impossible de se connecter à l'API."
        exit 2
    fi

    # Vérification du hash suffixe dans la réponse
    echo "$RESPONSE" | grep "$TAILSHA" | cut -d ':' -f 2
}

# Demande du mot de passe si aucun argument n'est fourni
if [[ -n "$1" ]]; then
    PASS="$1"
else
    stty -echo  # Désactive l'affichage
    echo -n "Entrez le mot de passe à vérifier : "
    read PASS
    stty echo   # Réactive l'affichage
    echo        # Nouvelle ligne après la saisie
fi

# Validation de l'entrée utilisateur
if [[ -z "$PASS" ]]; then
    echo "Erreur : Le mot de passe ne peut pas être vide. Arrêt du programme."
    exit 1
fi

# Lancer la vérification
RESULT=$(check_password "$PASS")
PASS='' # Nettoyage de la variable

# Affichage des résultats
if [[ -n "$RESULT" ]]; then
    RESULT=$(echo "$RESULT" | tr -d '\r')
    echo "Votre mot de passe a été trouvé $RESULT fois dans la base de données. Vous devriez le changer."
    exit 1
else
    echo "Bonne nouvelle ! Votre mot de passe n'est pas présent dans la base de données Have I Been Pwned."
    exit 0
fi
