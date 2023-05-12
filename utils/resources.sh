#!/bin/bash

pull_replicas() {
    local app_name
    app_name="$1"

    midclt call chart.release.get_instance "$app_name" | jq '.config.controller.replicas // .config.workload.main.replicas // .pod_status.desired'
}

scale_resources() {
    local app_name timeout replicas deployment_name
    app_name="$1"
    timeout="$2"
    replicas="${3:-$(pull_replicas "$app_name")}"
    deployment_name="$4"

    if [[ -z "$deployment_name" ]]; then
        # No specific deployment passed, scale all applicable deployments in the app
        k3s kubectl get deployments -n ix-"$app_name" -o json | jq -r '.items[] | select(.metadata.name | contains("-cnpg-main-") | not) | .metadata.name' | xargs -r -I{} k3s kubectl scale deployments/{} -n ix-"$app_name" --replicas="$replicas"
    else
        # Specific deployment passed, scale only this deployment
        k3s kubectl scale deployments/"$deployment_name" -n ix-"$app_name" --replicas="$replicas"
    fi

    if [[ $replicas -eq 0 ]]; then
        wait_for_pods_to_stop "$app_name" "$timeout" "$deployment_name" && return 0 || return 1
    fi
}


restart_app(){
    # There are no good labels to use to identify the deployment, so we have to simply filter out the cnpg deployment for now
    dep_name=$(k3s kubectl -n ix-"$app_name" get deploy | grep -vE -- '(-cnpg-)' | sed -e '1d' -e 's/ .*//')
    if k3s kubectl -n ix-"$app_name" rollout restart deploy "$dep_name" &>/dev/null; then
        return 0
    else
        return 1
    fi
}