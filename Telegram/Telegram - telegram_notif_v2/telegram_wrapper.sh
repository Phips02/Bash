#!/bin/bash
# Ce script sera exécuté avec setuid root

source /etc/telegram/notif_connexion/telegram.config 2>/dev/null
/usr/local/bin/telegram/notif_connexion/telegram.sh "$@" 