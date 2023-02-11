#!/bin/bash


mount(){
    ix_apps_pool=$(cli -c 'app kubernetes config' | 
                   grep -E "pool\s\|" | 
                   awk -F '|' '{print $3}' | 
                   sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//')

    # Use mapfile command to read the output of cli command into an array
    mapfile -t pool_query < <(cli -m csv -c "storage pool query name,path" | sed -e '1d' -e '/^$/d')

    # Add an option for the root directory
    pool_query+=("root,/mnt")
    while true
    do
        clear -x
        title
        echo -e "${bold}PVC Mount Menu${reset}"
        echo -e "${bold}--------------${reset}"
        echo -e "1)  Mount"
        echo -e "2)  Unmount All"
        echo
        echo -e "0)  Exit"
        read -rt 120 -p "Please type a number: " selection || { echo -e "\n${red}Failed to make a selection in time${reset}" ; exit; }
        case $selection in
            0)
                echo -e "Exiting.."
                exit
                ;;
            1)
                mount_app_func
                exit
                ;;
            2)
                unmount_app_func
                exit
                ;;
            *)
                echo -e "${red}Invalid selection, ${blue}\"$selection\"${red} was not an option${reset}" 
                sleep 3
                continue
                ;;
        esac
    done
}
export -f mount


mount_app_func(){
    call=$(k3s kubectl get pvc -A | 
                sort -u | 
                awk '{print $1 "\t" $2 "\t" $4}' | 
                sed "s/^0/ /")
    mount_list=$(echo -e "$call" | sed 1d | nl -s ") ")
    mount_title=$(echo -e "$call" | head -n 1)
    output="${blue}# $mount_title${reset}\n"
    counter=0
    while read -r line; do
        if [ $((++counter % 2)) -eq 0 ]; then
            output+="${gray}$line${reset}\n"
        else
            output+="$line\n"
        fi
    done <<< "$mount_list"
    list=$(echo -e "$output")

    declare -A mount_map
    counter=1
    for line in $list; do
        mount_map[$counter]="$line"
        counter=$((counter+1))
    done



    while true
    do
        clear -x
        title
        echo -e "$output" 
        echo 
        echo -e "0)  Exit"
        read -rt 120 -p "Please type a number: " selection || { echo -e "\n${red}Failed to make a selection in time${reset}" ; exit; }

        #Check for valid selection. If no issues, continue
        if [[ $selection == 0 ]]; then
            echo -e "Exiting.."
            exit
        fi
        line="${mount_map[$selection]}"
        if [[ -z "$line" ]]; then
            echo -e "${red}Invalid Selection: ${blue}$selection${red}, was not an option${reset}"
            sleep 3
            continue 
        fi
        app=$(echo -e "$line" | awk '{print $2}' | cut -c 4- )
        pvc=$(echo -e "$line")

        #Stop applicaiton if not stopped
        status=$(cli -m csv -c 'app chart_release query name,status' | 
                    grep "^$app," | 
                    awk -F ',' '{print $2}'| 
                    sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//')
        if [[ "$status" != "STOPPED" ]]; then
            echo -e "\nStopping ${blue}$app${reset} prior to mount"
            if ! cli -c 'app chart_release scale release_name='\""$app"\"\ 'scale_options={"replica_count": 0}' &> /dev/null; then
                echo -e "${red}Failed to stop ${blue}$app${reset}"
                exit 1
            else
                echo -e "${green}Stopped${reset}"
            fi
        else
            echo -e "\n${green}$app is already stopped${reset}"
        fi
        sleep 2

        #Grab data then output and mount
        data_name=$(echo -e "$pvc" | awk '{print $3}')
        volume_name=$(echo -e "$pvc" | awk '{print $4}')
        full_path=$(zfs list -t filesystem -r "$ix_apps_pool/ix-applications/releases/$app/volumes" -o name -H | grep "$volume_name")


        # Loop until a valid selection is made
        while true
        do
            clear -x
            title
            echo -e "${bold}Selected App:${reset} ${blue}$app${reset}"
            echo -e "${bold}Selected PVC:${reset} ${blue}$data_name${reset}"
            echo
            echo -e "Available Pools:"

            i=0
            # Print options with numbers
            for line in "${pool_query[@]}"; do
                (( i++ ))
                pool=$(echo -e "$line" | awk -F ',' '{print $1}')
                path=$(echo -e "$line" | awk -F ',' '{print $2}')
                echo -e "$i) $pool $path"
            done

            # Ask user for input
            echo
            read -r -t 120 -p "Please select a pool by number: " pool_num || { echo -e "${red}Failed to make a selection in time${reset}" ; exit; }


            # Check if the input is valid
            if [[ $pool_num -ge 1 && $pool_num -le ${#pool_query[@]} ]]; then
                selected_pool="${pool_query[pool_num-1]}"
                # Exit the loop
                break
            else
                echo -e "${red}Invalid selection please try again${reset}" 
                sleep 3
            fi
        done


        # Assign the selected pool and path to variables
        path=$(echo "$selected_pool" | awk -F ',' '{print $2}' | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//')
        pool_name=$(echo "$selected_pool" | awk -F ',' '{print $1}' | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//')


        # Check if the folder "mounted_pvc" exists on the selected pool
        if [ ! -d "$path/mounted_pvc" ]; then
            # If it doesn't exist, create it
            mkdir "$path/mounted_pvc"
        fi


        clear -x
        title
        if  [[ $pool_name == "root" ]]; then
            # Mount the PVC to the selected dataset                    
            if ! zfs set mountpoint=/mounted_pvc/"$data_name" "$full_path" ; then
                mount_failure=true
            fi
            root_mount=true
        else
            # Mount the PVC to the selected dataset                    
            if ! zfs set mountpoint=/"$pool_name"/mounted_pvc/"$data_name" "$full_path" ; then
                mount_failure=true
            fi
        fi


        echo -e "${bold}Selected App:${reset} ${blue}$app${reset}"
        echo -e "${bold}Selected PVC:${reset} ${blue}$data_name${reset}"
        echo -e "${bold}Selected Pool:${reset} ${blue}$pool_name${reset}"
        echo -e "${bold}Mounted To:${reset} ${blue}$path/mounted_pvc/$data_name${reset}"
        if [[ $mount_failure != true ]]; then
            echo -e "${bold}Status:${reset} ${green}Successfully Mounted${reset}"
        else
            echo -e "${bold}Status:${reset} ${red}Mount Failure${reset}"
        fi
        echo
        if [[ $root_mount == true ]]; then
            echo -e "${bold}Unmount Manually with:${reset}\n${blue}zfs set mountpoint=legacy \"$full_path\" && rmdir /mnt/mounted_pvc/$data_name${reset}"
        else
            echo -e "${bold}Unmount Manually with:${reset}\n${blue}zfs set mountpoint=legacy \"$full_path\" && rmdir /mnt/*/mounted_pvc/$data_name${reset}"
        fi
        echo
        echo -e "Or use the Unmount All option"


        
        #Ask if user would like to mount something else
        while true
        do
            echo
            read -rt 120 -p "Would you like to mount anything else? (y/N): " yesno || { echo -e "\n${red}Failed to make a selection in time${reset}" ; exit; }
            case $yesno in
            [Yy] | [Yy][Ee][Ss])
                clear -x
                title
                break
                ;;
            [Nn] | [Nn][Oo])
                exit
                ;;
            *)
                echo -e "${red}Invalid selection ${blue}\"$yesno\"${red} was not an option${reset}" 
                sleep 3
                continue
                ;;
            esac
        done
    done
}


unmount_app_func(){
    # Create an empty array to store the results
    unmount_array=()

    # Iterate through all available pools
    for line in "${pool_query[@]}"; do
        pool_path=$(echo "$line" | awk -F ',' '{print $2}' | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//')
        # Check if the folder "mounted_pvc" exists in the current pool
        if [ -d "$pool_path/mounted_pvc" ]; then
            # If it exists, add the contents of the folder to the unmount_array
            mapfile -t unmount_array_temp < <(find "$pool_path/mounted_pvc" -mindepth 1 -maxdepth 1 -type d -printf '%f\n')
            unmount_array+=("${unmount_array_temp[@]}")
        fi
    done

    # Check if the unmount_array is empty
    if [[ -z ${unmount_array[*]} ]]; then
        echo -e "${yellow}There are no PVCS to unmount.${reset}"
        return
    fi

    for pvc_name in "${unmount_array[@]}"; do
        # Get the PVC details
        main=$(k3s kubectl get pvc -A | grep -E "\s$pvc_name\s" | awk '{print $1, $2, $4}')
        app=$(echo -e "$main" | awk '{print $1}' | cut -c 4-)
        pvc=$(echo -e "$main" | awk '{print $3}')
        full_path=$(find "/mnt/$ix_apps_pool/ix-applications/releases/$app/volumes/" -maxdepth 0 | cut -c 6-)

        # Set the mountpoint to "legacy" and unmount
        if zfs set mountpoint=legacy "$full_path""$pvc"; then
            echo -e "${blue}$pvc_name ${green}unmounted successfully.${reset}"
            rmdir /mnt/*/mounted_pvc/"$pvc_name" 2>/dev/null || rmdir /mnt/mounted_pvc/"$pvc_name" 2>/dev/null
        else
            echo -e "${red}Failed to unmount ${blue}$pvc_name.${reset}"
        fi

    done

    # Remove the mounted_pvc directory if it's empty
    rmdir /mnt/*/mounted_pvc 2>/dev/null ; rmdir /mnt/mounted_pvc 2>/dev/null
}