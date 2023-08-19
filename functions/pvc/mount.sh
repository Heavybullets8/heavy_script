#!/bin/bash

# Retrieves the application pool.
pvc_retrieve_app_pool() {
    ix_apps_pool=$(cli -c 'app kubernetes config' | 
                   grep -E "pool\s\|" | 
                   awk -F '|' '{print $3}' | 
                   sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//')
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
            pvc_mount_pvc "$app" "$data_name" "$full_path"
        else
            echo -e "${red}Error:${reset} Could not find a ZFS path for $data_name"
        fi
    done

    echo -e "${bold}──────────────────────────────────────────────${reset}"
    echo -e "${bold}To Unmount All at Once:${reset}"
    echo -e "${blue}heavyscript pvc --unmount${reset}\n"
}

pvc_select_app() {
    mapfile -t apps < <(cli -m csv -c 'app chart_release query name' | tail -n +2 | sort | tr -d " \t\r" | awk 'NF')

    while true; do
        # Display apps with numbers
        echo -e "\nSelect an App:"
        for i in "${!apps[@]}"; do
            echo "$((i+1))) ${apps[$i]}"
        done
        
        # Provide option to exit
        echo -e "0) Exit\n"

        # Get user input
        read -rp "Please type a number: " selection

        # Exit if user selects 0
        if [[ "$selection" == "0" ]]; then
            echo "Exiting..."
            exit 0
        fi

        # If user input is valid, echo the app name and break out of loop
        if [[ "$selection" -ge 1 && "$selection" -le "${#apps[@]}" ]]; then
            app="${apps[$((selection-1))]}"
            break
        else
            # Display an error message for invalid selection
            echo -e "\n${red}Invalid Selection: ${blue}$selection${red}, was not an option${reset}"
        fi
    done
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
    app=""

    pvc_retrieve_app_pool

    if [[ -z $manual_selection ]]; then
        pvc_select_app
    else
        app=$manual_selection
        #verify app is valid
        mapfile -t apps < <(cli -m csv -c 'app chart_release query name' | tail -n +2 | sort | tr -d " \t\r" | awk 'NF')
        if [[ ! " ${apps[*]} " =~ " ${app} " ]]; then
            echo -e "${red}Error:${reset} $app is not a valid app"
            exit 1
        fi
    fi

    pvc_stop_selected_app "$app"
    sleep 2

    pvc_mount_all_in_namespace "$app"


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
