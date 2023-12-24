#!/bin/bash

check_mounted(){
    local app_name=$1

    if [[ -d /mnt/mounted_pvc/"$app_name" ]]; then
        unmount_app_func "$app_name" > /dev/null 2>&1
    fi
}



start_app(){
    local app_name=$1

    #check if app is currently mounted
    check_mounted "$app_name"

    # Check if app is a cnpg instance, or an operator instance
    output=$(check_filtered_apps "$app_name")

    if [[ $output == *"${app_name},stopAll-on"* ]]; then
        # Disable stopAll
        if ! cli -c "app chart_release update chart_release=\"$app_name\" values={\"global\": {\"stopAll\": true}}" > /dev/null 2>&1; then 
            return 1
        fi

        replicas=$(pull_replicas "$app_name")
        # Scale up application
        if ! cli -c 'app chart_release scale release_name='\""$app_name"\"\ 'scale_options={"replica_count": '"$replicas}" > /dev/null 2>&1; then
            return 1
        fi

    else
        replicas=$(pull_replicas "$app_name")
        if ! cli -c 'app chart_release scale release_name='\""$app_name"\"\ 'scale_options={"replica_count": '"$replicas}" > /dev/null 2>&1; then
            return 1
        fi
    fi
    return 0
}
