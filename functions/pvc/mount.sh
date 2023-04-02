#!/bin/bash


mount_app_func(){
    ix_apps_pool=$(cli -c 'app kubernetes config' | 
                   grep -E "pool\s\|" | 
                   awk -F '|' '{print $3}' | 
                   sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//')

    # Use mapfile command to read the output of cli command into an array
    mapfile -t pool_query < <(cli -m csv -c "storage pool query name,path" | sed -e '1d' -e '/^$/d')

    # Run the command and store the output in an array
    readarray -t output < <(k3s kubectl get pvc -A | sort -u | awk '{print $1 "\t" $2 "\t" $4}' | sed "s/^0/ /")

    # Assign a number to each element of the array, except for the first one
    count=0
    for ((i=1; i<${#output[@]}; i++)); do
        output[i]="$((i))) ${output[i]}"
        count=$((count+1))
    done

    while true
    do
        clear -x
        title
        # Format the output for display
        for ((i=0; i<${#output[@]}; i++)); do
            if [[ $i -eq 0 ]]; then
                echo -e "${blue}# ${output[i]}${reset}"
            else
                if [[ $((i % 2)) -eq 0 ]]; then
                    echo -e "${gray}${output[i]}${reset}"
                else
                    echo -e "${output[i]}"
                fi
            fi
        done | column -t 
        echo 
        echo -e "0)  Exit"
        read -rt 120 -p "Please type a number: " selection || { echo -e "\n${red}Failed to make a selection in time${reset}" ; exit; }

        #Check for valid selection. If no issues, continue
        if [[ $selection == 0 ]]; then
            echo -e "Exiting.."
            exit
        fi
        app=$(echo -e "${output[selection]}" | awk '{print $2}' | cut -c 4- )

        if [[ -z "$app" ]]; then
            echo -e "${red}Invalid Selection: ${blue}$selection${red}, was not an option${reset}"
            sleep 3
            continue 
        fi

        entire_line=$(echo -e "${output[selection]}")

        #Stop applicaiton if not stopped
        status=$(cli -m csv -c 'app chart_release query name,status' | 
                    grep "^$app," | 
                    awk -F ',' '{print $2}'| 
                    sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//')
        if [[ "$status" != "STOPPED" ]]; then
            echo -e "\nStopping ${blue}$app${reset} prior to mount"
            stop_app "normal" "$app" "${timeout:-50}"
            result=$(handle_stop_code "$?")
            if [[ $? -eq 1 ]]; then
                echo -e "${red}${result}${reset}"
                exit 1
            else
                echo -e "${green}${result}${reset}"
            fi
        fi
        sleep 2

        #Grab data then output and mount
        data_name=$(echo -e "$entire_line" | awk '{print $3}')
        volume_name=$(echo -e "$entire_line" | awk '{print $4}')
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

            # Generate header
            header="${blue}#\tPool\tPath\tAvailable Capacity${reset}"

            # Generate rows
            rows=()
            i=0
            for line in "${pool_query[@]}"; do
                (( i++ ))
                pool=$(echo -e "$line" | awk -F ',' '{print $1}' | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//')
                path=$(echo -e "$line" | awk -F ',' '{print $2}' | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//')
                avail=$(
                zfs list -p -o name,avail "$pool" \
                | grep -o '[0-9]*$' \
                | awk '{
                    if ($1/1024/1024/1024/1024 >= 1)
                        printf "%.2fTB", $1/1024/1024/1024/1024
                    else
                        printf "%.2fGB", $1/1024/1024/1024
                }'
                )
                rows+=("$i)\t$pool\t$path\t$avail")
            done

            # Add an option for the root directory
            root_num=$((i+1))
            root_avail=$(
            zfs list -p -o name,avail boot-pool \
            | grep -o '[0-9]*$' \
            | awk '{
                if ($1/1024/1024/1024/1024 >= 1)
                    printf "%.2fTB", $1/1024/1024/1024/1024
                else
                    printf "%.2fGB", $1/1024/1024/1024
            }'
            )
            rows+=("$root_num)\troot\t/mnt\t$root_avail")

            # Print output with header and rows formatted in columns
            printf "%b\n" "$header" "${rows[@]}" | column -t -s $'\t'

            # Ask user for input
            echo
            read -r -t 120 -p "Please select a pool by number: " pool_num || { echo -e "${red}Failed to make a selection in time${reset}" ; exit; }

            # Check if the input is valid
            if [[ $pool_num -ge 1 && $pool_num -le ${#rows[@]} ]]; then
                selected_pool=$(echo -e "${rows[pool_num-1]}")
                # Exit the loop
                break
            else
                echo -e "${red}Invalid selection please try again${reset}" 
                sleep 3
            fi
        done

        # Assign the selected pool and path to variables
        path=$(echo "$selected_pool" | awk -F '\t' '{print $3}' | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//')
        pool_name=$(echo "$selected_pool" | awk -F '\t' '{print $2}' | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//')

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
            [Nn] | [Nn][Oo]|"")
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