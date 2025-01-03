#!/bin/bash

# Fonctions utilitaires communes
check_command() {
    command -v "$1" >/dev/null 2>&1
}

check_dependencies() {
    local missing=()
    for cmd in "$@"; do
        check_command "$cmd" || missing+=("$cmd")
    done
    
    if [[ ${#missing[@]} -gt 0 ]]; then
        print_log "ERROR" "system" "Dépendances manquantes: ${missing[*]}"
        return 1
    fi
    return 0
}

is_root() {
    [[ $EUID -eq 0 ]]
}

check_file_permissions() {
    local file="$1"
    local expected_perms="$2"
    
    [[ $(stat -c %a "$file") == "$expected_perms" ]]
}
