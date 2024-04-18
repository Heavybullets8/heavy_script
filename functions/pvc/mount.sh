#!/bin/bash


pvc_mount_all_in_namespace() {
    local app=$1
    local pvc_list
    local results=()
    local mount_point="/mnt/mounted_pvc/$app"

    clear -x
    echo -e "${blue}Mounting PVC's for $app...${reset}"
    mapfile -t pvc_list < <(k3s kubectl get pvc -n "ix-$app" | awk 'NR>1 {print $1}' | grep -v -- "-cnpg-main")
    
    for data_name in "${pvc_list[@]}"; do
        local volume_name full_path status_color status

        volume_name=$(k3s kubectl get pvc "$data_name" -n "ix-$app" -o=jsonpath='{.spec.volumeName}')
        parent_path=$(k3s kubectl describe pv "$volume_name" | grep "poolname=" | awk -F '=' '{print $2}')
        full_path="${parent_path}/${volume_name}"

        if [[ -n "$volume_name" && -n "$parent_path" ]]; then
            if pvc_mount_pvc "$app" "$data_name" "$full_path"; then
                status="Success"
                status_color="$green"
            else
                status="Failure"
                status_color="$red"
            fi
        else
            status="Error: Could not find PV path"
            status_color="$red"
        fi
        results+=("$data_name" "$status_color$status")
    done

    clear -x
    title

    # Now print the consolidated output
    echo -e "${bold}PVC's:${reset}"
    for ((i=0; i<${#results[@]}; i+=2)); do
        echo -e "    ${results[$i+1]}$reset: $blue${results[$i]}$reset"
    done
    echo -e "${bold}Mounted to:${reset} ${blue}$mount_point${reset}"
    echo -e "${bold}Unmount with: ${blue}heavyscript pvc --unmount $app${reset}\n"
}

pvc_select_app() {
    clear -x
    echo -e "${blue}Fetching applications..${reset}"
    mapfile -t apps < <(cli -m csv -c 'app chart_release query name' | tail -n +2 | sort | tr -d " \t\r" | awk 'NF')

    while true; do
        clear -x
        title
        echo -e "\nSelect an App:"
        for i in "${!apps[@]}"; do
            echo "$((i+1))) ${apps[$i]}"
        done
        
        echo -e "\n0) Exit\n"

        read -rp "Please type a number: " selection

        if [[ "$selection" == "0" ]]; then
            echo "Exiting..."
            exit 0
        fi

        if [[ "$selection" -ge 1 && "$selection" -le "${#apps[@]}" ]]; then
            app="${apps[$((selection-1))]}"
            break
        else
            echo -e "\n${red}Invalid Selection: ${blue}$selection${red}, was not an option${reset}"
        fi
    done
}

pvc_mount_pvc() {
    local app=$1
    local data_name=$2
    local full_path=$3

    # Try to mount the PVC and return whether it was successful
    if ! zfs set mountpoint="/mounted_pvc/$app/$data_name" "$full_path"; then
        return 1
    else
        return 0
    fi
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

pvc_check_for_pvc(){
    if k3s kubectl get pvc -n "ix-$app" --no-headers 2>/dev/null | grep -q .;then
        return 0
    else
        echo -e "${yellow}$app, does not contain any PVC's${reset}"
        exit 1
    fi
}

#shellcheck disable=SC2120
mount_app_func() {
    local manual_selection=$1
    app=""

    pvc_retrieve_app_pool

    if [[ -z $manual_selection ]]; then
        pvc_select_app
    else
        clear -x
        echo -e "${blue}Validating app...${reset}"
        app=${manual_selection,,}
        if ! check_app_existence "$app"; then
            echo -e "${red}Error:${reset} $manual_selection does not exist"
            exit 1
        fi
    fi

    pvc_check_for_pvc

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
                mount_app_func
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
