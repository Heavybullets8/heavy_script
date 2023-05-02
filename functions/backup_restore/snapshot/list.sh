#!/bin/bash


list_backups_func(){
    clear -x && echo -e "${blue}pulling restore points..${reset}"

    list_backups=$(cli -c 'app kubernetes list_backups' | tr -d " \t\r" | sed '1d;$d')

    # heavyscript backups
    mapfile -t hs_tt_backups < <(echo -e "$list_backups" | 
                                 grep -E "HeavyScript_|Truetool_" | 
                                 sort -t '_' -Vr -k2,7 | 
                                 awk -F '|'  '{print $2}')

    # system backups
    mapfile -t system_backups < <(echo -e "$list_backups" | 
                                  grep "system-update--" | 
                                  sort -t '-' -Vr -k3,5 | 
                                  awk -F '|'  '{print $2}')

    # other backups
    mapfile -t other_backups < <(echo -e "$list_backups" | 
                                 grep -v -E "HeavyScript_|Truetool_|system-update--" | 
                                 sort -t '-' -Vr -k3,5 | 
                                 awk -F '|'  '{print $2}')


    #Check if there are any restore points
    if [[ ${#hs_tt_backups[@]} -eq 0 ]] && [[ ${#system_backups[@]} -eq 0 ]] && [[ ${#other_backups[@]} -eq 0 ]]; then
        echo -e "${yellow}No restore points available${reset}"
        exit
    fi


    # Initialize the restore_points array
    restore_points=()

    # Append the elements of the hs_tt_backups array
    for i in "${hs_tt_backups[@]}"; do
        restore_points+=("$i")
    done

    # Append the elements of the system_backups array
    for i in "${system_backups[@]}"; do
        restore_points+=("$i")
    done

    # Append the elements of the other_backups array
    for i in "${other_backups[@]}"; do
        restore_points+=("$i")
    done


    # Add line numbers to the array elements
    for i in "${!restore_points[@]}"; do
        restore_points[i]="$((i+1))) ${restore_points[i]}"
    done
}
export -f list_backups_func