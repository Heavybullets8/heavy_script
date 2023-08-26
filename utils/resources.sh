#!/bin/bash

pull_replicas() {
    local app_name
    app_name="$1"

    midclt call chart.release.get_instance "$app_name" | jq '.config.controller.replicas // .config.workload.main.replicas'
}

restart_app(){
    # Check if the namespace exists
    if ! k3s kubectl get namespace ix-"$app_name" &>/dev/null; then
        return 1
    fi

    # Get deployments excluding the cnpg ones
    mapfile -t dep_names < <(k3s kubectl -n ix-"$app_name" get deploy | grep -vE -- '(-cnpg-)' | awk 'NR>1 {print $1}')

    # Check if there are any valid deployments to restart
    if [[ ${#dep_names[@]} -eq 0 ]]; then
        return 1
    fi

    # Restart each deployment
    for dep_name in "${dep_names[@]}"; do
        if ! k3s kubectl -n ix-"$app_name" rollout restart deploy "$dep_name" &>/dev/null; then
            return 1
        fi
    done
    return 0
}