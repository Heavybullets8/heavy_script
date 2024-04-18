#!/bin/bash

unmount_app_menu(){
    # Use the find command to search for directories within /mnt/mounted_pvc/
    mapfile -t mounted_apps < <(find /mnt/mounted_pvc/ -mindepth 1 -maxdepth 1 -type d -printf '%f\n' 2>/dev/null)

    # Check if the mounted_apps array is empty
    if [[ -z ${mounted_apps[*]} ]]; then
        echo -e "${yellow}There are no PVCs to unmount.${reset}"
        rmdir /mnt/mounted_pvc 2>/dev/null
        exit
    else
        while true; do
            # Display the menu
            echo "Currently mounted apps:"
            for i in "${!mounted_apps[@]}"; do
                echo "$((i+1))) ${mounted_apps[$i]}"
            done

            # Add 'All' and 'Exit' options
            echo "$(( ${#mounted_apps[@]} + 1 ))) All"
            echo -e "\n0) Exit"

            read -rp "Please select an app to unmount, choose 'All' or 'Exit': " selection

            if [[ $selection -eq 0 ]]; then
                echo "Exiting..."
                return
            # Check if selection is 'All'
            elif [[ $selection -eq $(( ${#mounted_apps[@]} + 1 )) ]]; then
                apps=("${mounted_apps[@]}")
                return
            # Check if the selection is valid
            elif [[ $selection -ge 1 && $selection -le ${#mounted_apps[@]} ]]; then
                apps=("${mounted_apps[$((selection-1))]}")
                return
            else
                echo -e "${yellow}Invalid selection. Please try again.${reset}"
            fi
        done
    fi

}


unmount_app_func(){
    apps=("$1")

    for i in "${!apps[@]}"; do
        if [[ "${apps[$i]}" != "ALL" ]]; then
            apps[i]="${apps[$i],,}"
        fi
    done

    if [ ! -d "/mnt/mounted_pvc" ]; then
        echo -e "${yellow}There is nothing to unmount${reset}"
        exit 0
    fi

    if [[ $1 == "ALL" ]]; then
        mapfile -t apps < <(find /mnt/mounted_pvc/ -mindepth 1 -maxdepth 1 -type d -printf '%f\n' 2>/dev/null)
    elif [[ -z $1 ]]; then
        unmount_app_menu
    fi

    unmount_array=()

    for app in "${apps[@]}"; do
        # Check if the directory exists
        if [ ! -d "/mnt/mounted_pvc/$app" ]; then
            echo -e "${red}Error:${reset} The directory '/mnt/mounted_pvc/$app' does not exist."
            exit 1
        fi

        mapfile -t unmount_array < <(find "/mnt/mounted_pvc/$app" -mindepth 1 -maxdepth 1 -type d -printf '%f\n' 2>/dev/null)

        # Check if the unmount_array is empty
        if [[ -z ${unmount_array[*]} ]]; then
            echo -e "${yellow}$app's directory is empty, removing directory..${reset}"
            rmdir "/mnt/mounted_pvc/$app" 2>/dev/null 
            continue
        fi

        for pvc_name in "${unmount_array[@]}"; do
            local volume_name=""
            local parent_path=""

            volume_name=$(k3s kubectl get pvc "$pvc_name" -n "ix-$app" -o=jsonpath='{.spec.volumeName}')
            if [[ -z $volume_name ]]; then
                echo -e "${red}Error:${reset} Could not find volume name for PVC $pvc_name"
                continue
            fi
            parent_path=$(k3s kubectl describe pv "$volume_name" | grep "poolname=" | awk -F '=' '{print $2}')
            if [[ -z $parent_path ]]; then
                echo -e "${red}Error:${reset} Could not find parent path for volume $volume_name"
                continue
            fi

            full_path="$parent_path/$volume_name"

            for i in {1..5}; do
                # Attempt to set the mountpoint to "legacy"
                zfs set mountpoint=legacy "$full_path" &>/dev/null
                
                # Verify the mountpoint was set to "legacy"
                if zfs get mountpoint -Ho "value" "$full_path" | grep -q "legacy"; then
                    echo -e "${blue}$pvc_name ${green}unmounted successfully.${reset}"
                    rmdir "/mnt/mounted_pvc/${app}/${pvc_name}" 2>/dev/null
                    break 
                else
                    sleep 1
                fi
            done

            if [ "$i" -eq 5 ]; then
                echo -e "${red}Failed to unmount ${blue}$pvc_name${red} after 5 attempts.${reset}"
                echo -e "${yellow}Please make sure your terminal is not open in the mounted directory.${reset}"
            fi
        done
        rmdir "/mnt/mounted_pvc/$app" 2>/dev/null
    done

    # Remove the mounted_pvc directory if it's empty
    rmdir /mnt/mounted_pvc 2>/dev/null
}
