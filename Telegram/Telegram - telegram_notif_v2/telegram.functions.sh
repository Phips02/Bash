#!/bin/bash

# Fonction améliorée pour détecter l'IP source et le type de connexion
get_source_ip() {
    # Pour les connexions SSH directes
    if [ -n "$SSH_CONNECTION" ]; then
        echo "$SSH_CONNECTION" | awk '{print $1}'
        return
    fi

    # Pour les sessions su/sudo, trouver la session SSH parente
    local parent_ssh_ip=""
    
    # Vérifier si on est dans une session su
    if [ -z "$SSH_CONNECTION" ] && [ "$TERM" != "unknown" ]; then
        # Obtenir le PID du processus parent
        local ppid=$PPID
        while [ "$ppid" -ne 1 ]; do
            # Vérifier si le processus parent est une session SSH
            local parent_cmd=$(ps -o cmd= -p $ppid)
            if [[ "$parent_cmd" == *"sshd"* ]]; then
                parent_ssh_ip=$(ss -tnp | grep "$ppid" | awk '{print $3}' | cut -d':' -f1)
                break
            fi
            # Remonter au processus parent suivant
            ppid=$(ps -o ppid= -p $ppid)
        done
    fi

    if [ -n "$parent_ssh_ip" ]; then
        echo "$parent_ssh_ip"
    else
        echo "Indisponible"
    fi
} 