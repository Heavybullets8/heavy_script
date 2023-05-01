#!/bin/bash

create_backup(){
    retention=$1
    backup_type=$2
    export echo_backup=()
    declare timestamp
    timestamp=$(date '+%Y_%m_%d_%H_%M_%S')

    if [[ -z "$retention" ]]; then
        echo -e "Error: No number of backups specified" >&2
        return 1
    fi

    if [[ "$backup_type" != "update" ]]; then
        echo -e "${blue}Please wait while the backup is created..${reset}"
    fi

    echo_backup+=("🄱 🄰 🄲 🄺 🅄 🄿 🅂")
    echo_backup+=("Number of backups was set to $number_of_backups\n")

    backup_cnpg_databases "$retention" "$timestamp"

    create_snapshot "$retention" "$timestamp"

    #Dump the echo_array, ensures all output is in a neat order. 
    for i in "${echo_backup[@]}"
    do
        echo -e "$i"
    done
    echo
    echo

}