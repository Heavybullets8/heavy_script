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
    # Remove this first if statement after a while
    # it is only here to deal with previous errors for a while
    if [[ $output == *"${app_name},official"* ]]; then
        replicas=$(pull_replicas "$app_name")
        if ! cli -c 'app chart_release scale release_name='\""$app_name"\"\ 'scale_options={"replica_count": '"$replicas}" > /dev/null 2>&1; then
            return 1
        fi
    elif [[ $output == *"${app_name},stopAll-"* ]]; then
        # Get app pool path
        ix_apps_pool=$(get_apps_pool)

        # Get latest version
        latest_version=$(find "/mnt/$ix_apps_pool/ix-applications/releases/$app_name/charts" -maxdepth 1 -type d | 
                        awk -F'/' '{print $NF}' | 
                        sort -V | 
                        tail -n 1)

        # Helm upgrade command
        if ! KUBECONFIG="/etc/rancher/k3s/k3s.yaml" \
            helm upgrade -n "ix-$app_name" "$app_name" \
            "/mnt/$ix_apps_pool/ix-applications/releases/$app_name/charts/$latest_version" \
            --reuse-values \
            --set global.stopAll=false; then 
            return 1
        fi

    # elif [[ $output == *"${app_name},stopAll-off"* ]]; then
    #     job_id=$(midclt call chart.release.redeploy_internal "$app_name") || return 1
    #     wait_for_redeploy_methods "$app_name"
    #     midclt call core.job_abort "$job_id" > /dev/null 2>&1
    else
        replicas=$(pull_replicas "$app_name")
        if ! cli -c 'app chart_release scale release_name='\""$app_name"\"\ 'scale_options={"replica_count": '"$replicas}" > /dev/null 2>&1; then
            return 1
        fi
    fi
    return 0
}
