#!/bin/bash

create_backup(){
    retention=$1
    backup_type=$2
    export echo_backup=()
    declare timestamp
    timestamp=$(date '+%Y_%m_%d_%H_%M_%S')

    # Load the config.ini file if --no-config is not passed
    if [[ $no_config == false ]]; then
        read_ini "config.ini" --prefix DATABASES
    fi

    # Set the default option using the config file
    local db_backups_enabled="${DATABASES__databases__enabled:-true}"
    local dump_folder="${DATABASES__databases__dump_folder:-"./database_dumps"}"


    if [[ -z "$retention" ]]; then
        echo -e "Error: No number of backups specified" >&2
        return 1
    fi

    if [[ "$backup_type" != "update" ]]; then
        echo -e "${blue}Please wait while the backup is created..${reset}"
    fi

    echo_backup+=("🄱 🄰 🄲 🄺 🅄 🄿 🅂")
    echo_backup+=("Retention: $retention\n")

    if [[ "$db_backups_enabled" == "true" ]]; then
        backup_cnpg_databases "$retention" "$timestamp" "$dump_folder"
    fi

    create_snapshot "$retention" "$timestamp"

    #Dump the echo_array, ensures all output is in a neat order. 
    for i in "${echo_backup[@]}"
    do
        echo -e "$i"
    done
    echo
    echo

}