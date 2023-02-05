#!/bin/bash


backup(){
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



choose_restore(){
    #select a restore point
    count=1
    while true
    do
        clear -x
        title
        if [[ "$1" == "delete" ]]; then
            echo -e "${bold}Choose a restore point to delete${reset}"
        else
            echo -e "${bold}Choose a restore point to restore${reset}"
        fi
        echo

        {
        if [[ ${#hs_tt_backups[@]} -gt 0 ]]; then
            echo -e "${bold}# HeavyScript/Truetool_Backups${reset}"
            # Print the HeavyScript and Truetool backups with numbers
            for ((i=0; i<${#hs_tt_backups[@]}; i++)); do
                echo -e "$count) ${hs_tt_backups[i]}"
                ((count++))
            done
        fi


        # Check if the system backups array is non-empty
        if [[ ${#system_backups[@]} -gt 0 ]]; then
            echo -e "\n${bold}# System_Backups${reset}"
            # Print the system backups with numbers
            for ((i=0; i<${#system_backups[@]}; i++)); do
                echo -e "$count) ${system_backups[i]}"
                ((count++))
            done
        fi


        # Check if the other backups array is non-empty
        if [[ ${#other_backups[@]} -gt 0 ]]; then
            echo -e "\n${bold}# Other_Backups${reset}"
            # Print the other backups with numbers
            for ((i=0; i<${#other_backups[@]}; i++)); do
                echo -e "$count) ${other_backups[i]}"
                ((count++))
            done 
        fi
        } | column -t -L

        echo
        echo -e "0)  Exit"
        # Prompt the user to select a restore point
        read -rt 240 -p "Please type a number: " selection || { echo -e "\n${red}Failed to make a selection in time${reset}" ; exit; }

        # Check if the user wants to exit
        if [[ $selection == 0 ]]; then
            echo -e "Exiting.." 
            exit
        # Check if the user's input is empty
        elif [[ -z "$selection" ]]; then 
            echo -e "${red}Your selection cannot be empty${reset}"
            sleep 3
            continue
        else
            # Check if the user's selection is a valid option
            found=0
            for point in "${restore_points[@]}"; do
                if grep -q "$selection)" <<< "$point"; then
                    found=1
                    break
                fi
            done

            # If the user's selection is not a valid option, inform them and prompt them to try again
            if [[ $found -eq 0 ]]; then
                echo -e "${red}Invalid Selection: ${blue}$selection${red}, was not an option${reset}"
                sleep 3
                continue
            fi
            # Extract the restore point from the array
            restore_point=${restore_points[$((selection-1))]#*[0-9]) }
        fi
        # Break out of the loop
        break
    done
}
export -f choose_restore


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


deleteBackup(){
    while true; do
        list_backups_func

        choose_restore "delete"

        #Confirm deletion
        while true
        do
            clear -x
            echo -e "${yellow}WARNING:\nYou CANNOT go back after deleting your restore point${reset}" 
            echo -e "\n\n${yellow}You have chosen:\n${blue}$restore_point\n\n${reset}"
            read -rt 120 -p "Would you like to proceed with deletion? (y/N): " yesno  || { echo -e "\n${red}Failed to make a selection in time${reset}" ; exit; }
            case $yesno in
                [Yy] | [Yy][Ee][Ss])
                    echo -e "\nDeleting $restore_point"
                    cli -c 'app kubernetes delete_backup backup_name=''"'"$restore_point"'"' &>/dev/null || { echo -e "${red}Failed to delete backup..${reset}"; exit; }
                    echo -e "${green}Sucessfully deleted${reset}"
                    break
                    ;;
                [Nn] | [Nn][Oo])
                    echo -e "Exiting"
                    exit
                    ;;
                *)
                    echo -e "${red}That was not an option, try again${reset}"
                    sleep 3
                    continue
                    ;;
            esac
        done

        #Check if there are more backups to delete
        while true
        do
            read -rt 120 -p "Delete more backups? (y/N): " yesno || { echo -e "\n${red}Failed to make a selection in time${reset}" ; exit; }
            case $yesno in
                [Yy] | [Yy][Ee][Ss])
                    break
                    ;;
                [Nn] | [Nn][Oo])
                    exit
                    ;;
                *)
                    echo -e "${blue}$yesno ${red}was not an option, try again${reset}" 
                    sleep 2
                    continue
                    ;;

            esac

        done
    done
}
export -f deleteBackup


restore(){
    list_backups_func

    choose_restore "restore"

    ## Check to see if empty PVC data is present in any of the applications ##

    # Find all pv_info.json files two subfolders deep with the restore point name
    pool=$(cli -c 'app kubernetes config' | 
           grep -E "pool\s\|" | 
           awk -F '|' '{print $3}' | 
           tr -d sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//')
    files=$(find "$(find /mnt/"$pool"/ix-applications/backups -maxdepth 0 )" -name pv_info.json | grep "$restore_point")

    # Iterate over the list of files
    for file in $files; do
        # Check if the file only contains {} subfolders
        contents=$(cat "$file")
        if [[ "$contents" == '{}' ]]; then
            # Print the file if it meets the criterion
            file=$(echo -e "$file" | awk -F '/' '{print $7}')
            borked_array+=("${file}")
        fi
    done

    # Grab applications that are supposed to have PVC data
    mapfile -t apps_with_pvc < <(k3s kubectl get pvc -A | 
                                 sort -u | 
                                 awk '{print $1 "\t" $2 "\t" $4}' | 
                                 sed "s/^0/ /" | 
                                 awk '{print $1}' | 
                                 cut -c 4-)


    # Iterate over the list of applications with empty PVC data
    # Unset the application if it is not supposed to have PVC data
    for app in "${!borked_array[@]}"; do
        if ! printf '%s\0' "${apps_with_pvc[@]}" | grep -iFxqz "${app}" ; then
            unset "borked_array[$app]"
        else
            borked=True
        fi
    done


    # If there is still empty PVC data, exit
    if [[ $borked == True ]]; then
        echo -e "${yellow}Warning!:"
        echo -e "The following applications have empty PVC data:${reset}"
        for app in "${borked_array[@]}"; do
            echo -e "$app"
        done
        echo -e "${red}We have no choice but to exit"
        echo -e "If you were to restore, you would lose all of your application data"
        echo -e "If you are on Bluefin version: 22.12.0, and have not yet ran the patch, you will need to run it"
        echo -e "Afterwards you will be able to create backups and restore them"
        echo -e "This is a known ix-systems bug, and has nothing to do with HeavyScript${reset}"
        exit
    fi


    # Only run the check_restore_point_version function if the restore point is a HeavyScript or Truetool backup
    if [[ $restore_point =~ "HeavyScript_" || $restore_point =~ "Truetool_" ]]; then
        check_restore_point_version
    fi


    #Confirm restore
    while true
    do
        clear -x
        echo -e "${yellow}WARNING:\nThis is NOT guranteed to work${reset}"
        echo -e "${yellow}This is ONLY supposed to be used as a LAST RESORT${reset}"
        echo -e "${yellow}Consider rolling back your applications instead if possible${reset}"
        echo -e "\n\nYou have chosen:\n${blue}$restore_point${reset}\n\n"
        read -rt 120 -p "Would you like to proceed with restore? (y/N): " yesno || { echo -e "\n${red}Failed to make a selection in time${reset}" ; exit; }
        case $yesno in
            [Yy] | [Yy][Ee][Ss])
                pool=$(cli -c 'app kubernetes config' | 
                       grep -E "pool\s\|" | 
                       awk -F '|' '{print $3}' | 
                       sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//')

                # Set mountpoints to legacy prior to restore, ensures correct properties for the are set
                echo -e "\nSetting correct ZFS properties for application volumes.."
                for pvc in $(zfs list -t filesystem -r "$pool"/ix-applications/releases -o name -H | grep "volumes/pvc")
                do
                    if zfs set mountpoint=legacy "$pvc"; then
                        echo -e "${green}Success for - ${blue}\"$pvc\"${reset}"
                    else
                        echo -e "${red}Error: Setting properties for ${blue}\"$pvc\"${red}, failed..${reset}"
                    fi
                done

                # Ensure readonly is turned off
                if ! zfs set readonly=off "$pool"/ix-applications;then
                    echo -e "${red}Error: Failed to set ZFS ReadOnly to \"off\""
                    echo -e "After the restore, attempt to run the following command manually:"
                    echo -e "${blue}zfs set readonly=off $pool/ix-applications${reset}"
                fi

                echo -e "${green}Finished setting properties..${reset}"

                # Beginning snapshot restore
                echo -e "\nStarting restore, this will take a LONG time."
                if ! cli -c 'app kubernetes restore_backup backup_name=''"'"$restore_point"'"'; then
                    echo -e  "${red}Restore failed, exiting..${reset}"
                    exit 1
                fi
                exit
                ;;
            [Nn] | [Nn][Oo])
                echo -e "Exiting"
                exit
                ;;
            *)
                echo -e  "${red}That was not an option, try again..${red}"
                sleep 3
                continue
                ;;
        esac
    done
}
export -f restore




check_restore_point_version() {
    ## Check the restore point, and ensure it is the same version as the current system ##
    # Boot Query
    boot_query=$(cli -m csv -c 'system bootenv query created,realname')

    # Get the date of system version and when it was updated
    current_version=$(cli -m csv -c 'system version' | awk -F '-' '{print $3}')
    when_updated=$(echo -e "$boot_query" | 
                   grep "$current_version", | 
                   sed -n 's/.*\([0-9]\{4\}-[0-9]\{2\}-[0-9]\{2\}\)T\([0-9]\{2\}:[0-9]\{2\}\).*/\1\2/p' | 
                   tr -d -- "-:")

    # Get the date of the chosen restore point
    # Extract the date information from the restore point string, which is formatted as "restore_point_<date>_<time>"
    restore_point_date=$(echo -e "$restore_point" | awk -F '_' '{print $2 $3 $4 $5 $6}' | tr -d "_")


    # Grab previous version
    previous_version=$(echo -e "$boot_query" | sort -nr | grep -A 1 "$current_version," | tail -n 1)

    # Compare the dates
    while (("$restore_point_date" < "$when_updated" ))
    do
        clear -x
        echo -e "The restore point you have chosen is from an older version of Truenas Scale"
        echo -e "This is not recommended, as it may cause issues with the system"
        echo -e "Either that, or your systems date is incorrect.."
        echo
        echo -e "${bold}Current SCALE Information:"
        echo -e "${bold}Version:${reset}       ${blue}$current_version${reset}"
        echo -e "${bold}When Updated:${reset}  ${blue}$(echo -e "$restore_point" | awk -F '_' '{print $2 "-" $3 "-" $4}')${reset}"
        echo
        echo -e "${bold}Restore Point SCALE Information:${reset}"
        echo -e "${bold}Version:${reset}       ${blue}$(echo -e "$previous_version" | awk -F ',' '{print $1}')${reset}"
        echo -e "${bold}When Updated:${reset}  ${blue}$(echo -e "$previous_version" | awk -F ',' '{print $2}' | awk -F 'T' '{print $1}')${reset}"
        echo
        read -rt 120 -p "Would you like to proceed? (y/N): " yesno || { echo -e "\n${red}Failed to make a selection in time${reset}" ; exit; }
            case $yesno in
                [Yy] | [Yy][Ee][Ss])
                    echo -e "${green}Proceeding..${reset}"
                    sleep 3
                    break
                    ;;
                [Nn] | [Nn][Oo])
                    echo -e "Exiting"
                    exit
                    ;;
                *)
                    echo -e "${red}That was not an option, try again${reset}"
                    sleep 3
                    continue
                    ;;
            esac
    done
}