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

    replicas=$(pull_replicas "$app_name")
    if [[ -z "$replicas" || "$replicas" == "null" ]]; then
        return 1
    fi

    if [[ $output == *"${app_name},stopAll-"* ]]; then
        ix_apps_pool=$(get_apps_pool)
        if [[ -z "$ix_apps_pool" ]]; then
            return 1
        fi

        latest_version=$(midclt call chart.release.get_instance "$app_name" | jq -r ".chart_metadata.version")
        if [[ -z "$latest_version" ]]; then
            return 1
        fi

        if ! helm upgrade -n "ix-$app_name" "$app_name" \
            "/mnt/$ix_apps_pool/ix-applications/releases/$app_name/charts/$latest_version" \
            --kubeconfig "/etc/rancher/k3s/k3s.yaml" \
            --reuse-values \
            --set global.stopAll=false > /dev/null 2>&1; then 
            return 1
        fi

        # Wait for pods to start
        timeout=60
        SECONDS=0
        end=$((SECONDS + timeout))

        pods_started=false
        while [[ $SECONDS -lt $end ]]; do
            # Check if pods are in a running, container creating, or initializing
            if k3s kubectl get pods -n "ix-$app_name" | grep -qE 'Running|ContainerCreating|Init:'; then
                pods_started=true
                break
            fi
            sleep 5
        done

        # If pods haven't started, run the redeploy command
        if [ "$pods_started" = false ]; then
            if ! cli -c 'app chart_release redeploy release_name='\""$app_name"\" > /dev/null 2>&1; then
                return 1
            fi
        fi
    else
        if ! cli -c 'app chart_release scale release_name='\""$app_name"\"\ 'scale_options={"replica_count": '"$replicas}" > /dev/null 2>&1; then
            return 1
        fi
    fi
    return 0
}
