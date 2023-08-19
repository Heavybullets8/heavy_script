#!/bin/bash

pvc_retrieve_app_pool() {
    ix_apps_pool=$(cli -c 'app kubernetes config' | 
                   grep -E "pool\s\|" | 
                   awk -F '|' '{print $3}' | 
                   sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//')
}

pvc_format_output() {
    readarray -t output < <(k3s kubectl get pvc -A | sort -u | awk '{print $1 "\t" $2 "\t" $4}' | sed "s/^0/ /" | grep -v -- "-cnpg-main")
    
    for ((i=1; i<${#output[@]}; i++)); do
        output[i]="$((i))) ${output[i]}"
    done
}

pvc_mount_pvc() {
    local data_name=$1
    local full_path=$2

    if [ ! -d "/mnt/mounted_pvc" ]; then
        mkdir "/mnt/mounted_pvc"
    fi

    if ! zfs set mountpoint=/mounted_pvc/"$data_name" "$full_path"; then
        echo -e "${bold}Status:${reset} ${red}Mount Failure${reset}"
    else
        echo -e "${bold}Selected PVC:${reset} ${blue}$data_name${reset}"
        echo -e "${bold}Mounted To:${reset} ${blue}/mnt/mounted_pvc/$data_name${reset}"
        echo -e "${bold}Status:${reset} ${green}Successfully Mounted${reset}"
    fi
}

pvc_mount_all_in_namespace() {
    local app=$1
    local pvc_list

    mapfile -t pvc_list < <(k3s kubectl get pvc -n "ix-$app" | awk 'NR>1 {print $1}' | grep -v -- "-cnpg-main")

    
    for data_name in "${pvc_list[@]}"; do
        local volume_name full_path

        volume_name=$(k3s kubectl get pvc "$data_name" -n "ix-$app" -o=jsonpath='{.spec.volumeName}')
        full_path=$(zfs list -t filesystem -r "$ix_apps_pool/ix-applications/releases/$app/volumes" -o name -H | grep "$volume_name")
        if [ -n "$full_path" ]; then
            pvc_mount_pvc "$data_name" "$full_path"
            echo -e "${bold}Unmount Manually with:${reset}\n${blue}zfs set mountpoint=legacy \"$full_path\" && rmdir /mnt/mounted_pvc/$data_name${reset}"
        else
            echo -e "${red}Error:${reset} Could not find a ZFS path for $data_name"
        fi
    done

    echo -e "${bold}Unmount Manually with:${reset}\n${blue}zfs set mountpoint=legacy \"$full_path\" && rmdir /mnt/mounted_pvc/$data_name${reset}"
    echo -e "${bold}Or use the Unmount All option:${reset}\n${blue}heavyscript pvc --unmount${reset}"
}


pvc_display_output() {
    clear -x
    title
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
}

pvc_select_app() {
    while true; do
        pvc_display_output
        
        echo 
        echo -e "0)  Exit"
        read -rt 120 -p "Please type a number: " selection || { echo -e "\n${red}Failed to make a selection in time${reset}" ; exit; }

        if [[ $selection == 0 ]]; then
            echo -e "Exiting.."
            exit
        fi

        app=$(echo -e "${output[selection]}" | awk '{print $2}' | cut -c 4- )

        if [[ -z "$app" ]]; then
            echo -e "${red}Invalid Selection: ${blue}$selection${red}, was not an option${reset}"
            sleep 3
        else
            break
        fi
    done

    entire_line="${output[selection]}"
}

pvc_stop_selected_app() {
    local app=$1

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
}

mount_app_func() {
    local manual_selection=$1

    pvc_retrieve_app_pool

    if [[ -z $manual_selection ]]; then
        pvc_select_app
    else
        app=$manual_selection
    fi

    pvc_stop_selected_app "$app"
    sleep 2

    if [[ -n $manual_selection ]]; then
        pvc_mount_all_in_namespace "$app"
    fi

    local data_name volume_name full_path

    data_name=$(echo -e "$entire_line" | awk '{print $3}')
    volume_name=$(echo -e "$entire_line" | awk '{print $4}')
    full_path=$(zfs list -t filesystem -r "$ix_apps_pool/ix-applications/releases/$app/volumes" -o name -H | grep "/$volume_name$")


    if [ ! -d "/mnt/mounted_pvc" ]; then
        mkdir "/mnt/mounted_pvc"
    fi

    clear -x
    title

    if ! zfs set mountpoint=/mounted_pvc/"$data_name" "$full_path"; then
        echo -e "${bold}Status:${reset} ${red}Mount Failure${reset}"
    else
        echo -e "${bold}Selected App:${reset} ${blue}$app${reset}"
        echo -e "${bold}Selected PVC:${reset} ${blue}$data_name${reset}"
        echo -e "${bold}Mounted To:${reset} ${blue}/mnt/mounted_pvc/$data_name${reset}"
        echo -e "${bold}Status:${reset} ${green}Successfully Mounted${reset}"
    fi

    echo -e "${bold}Unmount Manually with:${reset}\n${blue}zfs set mountpoint=legacy \"$full_path\" && rmdir /mnt/mounted_pvc/$data_name${reset}"
    echo -e "${bold}Or use the Unmount All option:${reset}\n${blue}heavyscript pvc --unmount${reset}"

    if [[ -z $manual_selection ]]; then
        while true; do
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
    fi
}
