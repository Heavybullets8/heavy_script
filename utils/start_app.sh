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
        ix_apps_pool=$(get_apps_pool)

        latest_version=$(midclt call chart.release.get_instance "$app_name" | jq -r ".chart_metadata.version")

        if ! helm upgrade -n "ix-$app_name" "$app_name" \
            "/mnt/$ix_apps_pool/ix-applications/releases/$app_name/charts/$latest_version" \
            --kubeconfig "/etc/rancher/k3s/k3s.yaml" \
            --reuse-values \
            --set global.stopAll=false > /dev/null 2>&1; then 
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
