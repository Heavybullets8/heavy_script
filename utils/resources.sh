#!/bin/bash

pull_replicas() {
    local app_name
    app_name="$1"

    midclt call chart.release.get_instance "$app_name" | jq '.pod_status.desired'
}

restart_app(){
    # There are no good labels to use to identify the deployment, so we have to simply filter out the cnpg deployment for now
    dep_names=$(k3s kubectl -n ix-"$app_name" get deploy | grep -vE -- '(-cnpg-)' | sed -e '1d' -e 's/ .*//')
    for dep_name in $dep_names; do
        if ! k3s kubectl -n ix-"$app_name" rollout restart deploy "$dep_name" &>/dev/null; then
            return 1
        fi
    done
    return 0
}
