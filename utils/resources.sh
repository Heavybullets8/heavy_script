#!/bin/bash

pull_replicas() {
    local app_name
    app_name="$1"

    midclt call chart.release.get_instance "$app_name" | jq '.config.controller.replicas // .config.workload.main.replicas // .pod_status.desired'
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