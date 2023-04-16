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

    apply_scaling() {
        local resource_type
        resource_type="$1"
        k3s kubectl get "$resource_type" -n ix-"$app_name" -o custom-columns=':metadata.name' | grep -vE '^$|-cnpg-' | xargs -r -I{} k3s kubectl scale "$resource_type"/{} -n ix-"$app_name" --replicas="$replicas"
    }

    if [[ $replicas -eq 0 ]]; then
        # Scale down all Deployments, StatefulSets, and ReplicaSets in the namespace
        apply_scaling "deploy"
        apply_scaling "statefulsets"

        wait_for_pods_to_stop "$app_name" "$timeout" && return 0 || return 1
    else
        # Scale up all Deployments, StatefulSets, and ReplicaSets in the namespace
        apply_scaling"deploy"
        apply_scaling "statefulsets"
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