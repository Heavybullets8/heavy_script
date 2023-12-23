#!/bin/bash

pull_replicas() {
    local app_name
    app_name="$1"

    # First Check
    replica_info=$(midclt call chart.release.get_instance "$app_name" | jq '.config.workload.main.replicas // .config.controller.replicas')

    # Second Check if First Check returns null or 0
    if [[ "$replica_info" == "null" || "$replica_info" == "0" ]]; then
        replica_info=$(k3s kubectl get deployments -n "ix-$app_name" --selector=app.kubernetes.io/instance="$app_name" -o=jsonpath='{.items[*].spec.replicas}{"\n"}')
        # Replace 0 with 1
        replica_info=$(echo "$replica_info" | awk '{if ($1 == 0) $1 = 1; print $1}')
    fi

    # Output the replica info or "null" if neither command returned a result
    if [[ -z "$replica_info" || "$replica_info" == *" "* ]]; then
        echo "null"
    else
        echo "$replica_info"
    fi
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

get_apps_pool(){
    cli -c 'app kubernetes config' | 
        grep -E "pool\s\|" | 
        awk -F '|' '{print $3}' | 
        sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//'
}

check_app_existence() {
    local app=${1,,}
    mapfile -t apps < <(cli -m csv -c 'app chart_release query name' | tail -n +2 | sort | tr -d " \t\r" | awk 'NF')
    if [[ ! " ${apps[*]} " =~ ${app} ]]; then
        return 1
    fi
    return 0
}