#!/bin/bash


wait_for_pods_to_stop() {
    local app_name timeout
    app_name="$1"
    timeout="$2"

    SECONDS=0
    while k3s kubectl get pods -n ix-"$app_name" -o=name | grep -qv -- '-cnpg-'; do
        if [[ "$SECONDS" -gt $timeout ]]; then
            return 1
        fi
        sleep 1
    done
}

get_app_status() {
    local app_name stop_type
    app_name="$1"
    stop_type="$2"

    if [[ "$stop_type" == "update" ]]; then
        grep "^$app_name," all_app_status | awk -F ',' '{print $2}'
    else
        cli -m csv -c 'app chart_release query name,status' | \
            grep -- "^$app_name," | \
            awk -F ',' '{print $2}'
    fi
}

stop_app() {
    local stop_type app_name timeout status count
    stop_type="$1"
    app_name="$2"
    timeout="${3:-100}"

    if k3s kubectl get pods -n ix-"$app_name" -o=name | grep -q -- '-cnpg-'; then
        if ! k3s kubectl get deployments,statefulsets -n ix-"$app_name" | grep -vE -- "(NAME|^$|-cnpg-)" | awk '{print $1}' | xargs -I{} k3s kubectl scale --replicas=0 -n ix-"$app_name" {} &>/dev/null; then
            return 1
        fi
        wait_for_pods_to_stop "$app_name" "$timeout" && return 0 || return 1
    else
        for (( count=0; count<3; count++ )); do
            status=$(get_app_status "$app_name" "$stop_type")

            if [[ "$status" == "STOPPED" ]]; then
                return 0
            elif cli -c 'app chart_release scale release_name='\""$app_name"\"\ 'scale_options={"replica_count": 0}' &> /dev/null; then
                return 0
            else
                if [[ "$stop_type" == "update" ]]; then
                    before_loop=$(head -n 1 all_app_status)
                    until [[ $(head -n 1 all_app_status) != "$before_loop" ]]; do
                        sleep 1
                    done
                else
                    sleep 5
                fi
            fi
        done
    fi

    if [[ "$status" != "STOPPED" ]]; then
        return 1
    fi
}
