#!/bin/bash

pull_replicas() {
    local app_name
    app_name="$1"

    midclt call chart.release.get_instance "$app_name" | jq '.config.controller.replicas // .config.workload.main.replicas // .pod_status.desired'
}

scale_resources() {
    local app_name timeout replicas
    app_name="$1"
    timeout="$2"
    replicas="${3:-$(pull_replicas "$app_name")}"

    if ! k3s kubectl get deployments,statefulsets -n ix-"$app_name" -o custom-columns=':metadata.name' | grep -vE -- "^$|-cnpg-" | awk '{print $1}' | xargs -I{} k3s kubectl scale --replicas="$replicas" -n ix-"$app_name" {} &>/dev/null; then
        return 1
    fi

    if [[ $replicas -eq 0 ]]; then
        wait_for_pods_to_stop "$app_name" "$timeout" && return 0 || return 1
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