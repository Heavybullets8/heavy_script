#!/bin/bash

unmount_app_menu(){
    # Use the find command to search for directories within /mnt/mounted_pvc/
    mapfile -t mounted_apps < <(find /mnt/mounted_pvc/ -mindepth 1 -maxdepth 1 -type d -printf '%f\n' 2>/dev/null)

    # Check if the mounted_apps array is empty
    if [[ -z ${mounted_apps[*]} ]]; then
        echo -e "${yellow}There are no PVCs to unmount.${reset}"
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
        apps[i]="${apps[$i],,}"
    done

    ix_apps_pool=$(cli -c 'app kubernetes config' | 
                   grep -E "pool\s\|" | 
                   awk -F '|' '{print $3}' | 
                   sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//')

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

        mapfile -t unmount_array < <(find "/mnt/mounted_pvc/$app" -mindepth 1 -maxdepth 1 -type d -printf '%f\n' 2>/dev/null )

        # Check if the unmount_array is empty
        if [[ -z ${unmount_array[*]} ]]; then
            echo -e "${yellow}$app's directory is empty, removing directory..${reset}"
            rmdir "/mnt/mounted_pvc/$app" 2>/dev/null 
            continue
        fi

        for pvc_name in "${unmount_array[@]}"; do
            # Get the PVC details
            main=$(k3s kubectl get pvc --all-namespaces \
                --output="go-template={{range .items}}{{if eq .metadata.name \"$pvc_name\"}}\
                {{.metadata.name}} {{.spec.volumeName}}{{\"\n\"}}\
                {{end}}{{end}}")

            read -r pvc_name pvc <<< "$main"

            full_path="$ix_apps_pool/ix-applications/releases/$app/volumes"

            # Set the mountpoint to "legacy" and unmount
            if zfs set mountpoint=legacy "$full_path/$pvc"; then
                echo -e "${blue}$pvc_name ${green}unmounted successfully.${reset}"
                rmdir "/mnt/mounted_pvc/${app}/${pvc_name}" 2>/dev/null
            else
                echo -e "${red}Failed to unmount ${blue}$pvc_name.${reset}"
                echo -e "${yellow}Please make sure your terminal is not open in the mounted directory${reset}"
            fi
        done
        rmdir "/mnt/mounted_pvc/$app" 2>/dev/null
    done

    # Remove the mounted_pvc directory if it's empty
    rmdir /mnt/mounted_pvc 2>/dev/null
}