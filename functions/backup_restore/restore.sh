#!/bin/bash


restore_backup(){
    list_backups_func

    choose_restore "restore"

    ## Check to see if empty PVC data is present in any of the applications ##

    # Find all pv_info.json files two subfolders deep with the restore point name
    pool=$(cli -c 'app kubernetes config' | 
        grep -E "pool\s\|" | 
        awk -F '|' '{print $3}' | 
        sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//')
    files=$(find "$(find "/mnt/$pool/ix-applications/backups" -maxdepth 0 )" -name pv_info.json | grep "$restore_point")

    borked_array=()

    # Iterate over the list of files separated by newlines only
    while IFS= read -r file; do
    # Check if the file only contains {} subfolders
    contents=$(cat "$file")
    if [[ "$contents" == '{}' ]]; then
        # Print the file if it meets the criterion
        file=$(echo -e "$file" | awk -F '/' '{print $7}')
        borked_array+=("${file}")
    fi
    done < <(echo "$files")


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
                while IFS= read -r pvc; do
                    if zfs set mountpoint=legacy "$pvc"; then
                        echo -e "${green}Success for - ${blue}\"$pvc\"${reset}"
                    else
                        echo -e "${red}Error: Setting properties for ${blue}\"$pvc\"${red}, failed..${reset}"
                    fi
                done < <(zfs list -t filesystem -r "$pool/ix-applications/releases" -o name -H | grep "volumes/pvc")

                # Ensure readonly is turned off
                if ! zfs set readonly=off "$pool/ix-applications";then
                    echo -e "${red}Error: Failed to set ZFS ReadOnly to \"off\""
                    echo -e "After the restore, attempt to run the following command manually:"
                    echo -e "${blue}zfs set readonly=off \"$pool/ix-applications\"${reset}"
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