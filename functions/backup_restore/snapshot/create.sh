#!/bin/bash


create_backup(){
    if [[ -z "$1" ]]; then
        echo -e "Error: No number of backups specified" >&2
        return 1
    fi

    local number_of_backups="$1"
    local backup_type="$2"

    if [[ "$backup_type" != "update" ]]; then
        echo -e "${blue}Please wait while the backup is created..${reset}"
    fi

    echo_backup+=("🄱 🄰 🄲 🄺 🅄 🄿 🅂")
    echo_backup+=("Number of backups was set to $number_of_backups")

    # Get current date and time in a specific format
    current_date_time=$(date '+%Y_%m_%d_%H_%M_%S')

    # Create a new backup with the current date and time as the name
    if ! output=$(cli -c "app kubernetes backup_chart_releases backup_name=\"HeavyScript_$current_date_time\""); then
        echo -e "Error: Failed to create new backup" >&2
        return 1
    fi
    if [[ "$verbose" == true ]]; then
        echo_backup+=("$output")
    else
        echo_backup+=("\nNew Backup Name:" "$(echo -e "$output" | tail -n 1)")
    fi

    # Get a list of backups sorted by name in descending order
    mapfile -t current_backups < <(cli -c 'app kubernetes list_backups' | 
                                   grep -E "HeavyScript_|TrueTool_" | 
                                   sort -t '_' -Vr -k2,7 | 
                                   awk -F '|'  '{print $2}'| 
                                   tr -d " \t\r")

    # If there are more backups than the allowed number, delete the oldest ones
    if [[ ${#current_backups[@]} -gt "$number_of_backups" ]]; then
        echo_backup+=("\nDeleted the oldest backup(s) for exceeding limit:")
        overflow=$(( ${#current_backups[@]} - "$number_of_backups" ))
        # Place excess backups into an array for deletion
        mapfile -t list_overflow < <(cli -c 'app kubernetes list_backups' | 
                                     grep -E "HeavyScript_|TrueTool_"  | 
                                     sort -t '_' -V -k2,7 | 
                                     awk -F '|'  '{print $2}'| 
                                     tr -d " \t\r" | 
                                     head -n "$overflow")

        for i in "${list_overflow[@]}"; do
            cli -c "app kubernetes delete_backup backup_name=\"$i\"" &> /dev/null || echo_backup+=("Failed to delete $i")
            echo_backup+=("$i")
        done
    fi

    #Dump the echo_array, ensures all output is in a neat order. 
    for i in "${echo_backup[@]}"
    do
        echo -e "$i"
    done
    echo
    echo
}