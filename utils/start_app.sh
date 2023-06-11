#!/bin/bash

abort_job(){
    local app_name=$1
    job_id=""

    # shellcheck disable=SC2034
    for i in {1..60}; do
        job_id=$(get_running_job_id "$app_name")

        if [[ -n "$job_id" ]]; then
            midclt call core.job_abort "$job_id" > /dev/null 2>&1
            return 0
        fi

        sleep 1
    done
    return 1
}

get_running_job_id(){
    local app_name=$1
    midclt call core.get_jobs | jq -r --arg app_name "$app_name" \
        '.[] | select( .time_finished == null and .state == "RUNNING" and (.progress.description | test("Waiting for pods to be scaled to [0-9]+ replica\\(s\\)$")) and (.arguments[0] == $app_name and .method == "chart.release.scale") ) | .id'
}

start_app(){
    local app_name=$1
    local replica_count=${2:-$(pull_replicas "$app_name")}
    local job_id

    # Check if app is a cnpg instance, or an operator instance
    output=$(check_filtered_apps "$app_name")
    if [[ $output == *"${app_name},stopAll-on"* ]]; then
        midclt call chart.release.update "$app_name" '{"values": {"global": {"stopAll": false}}}'
        # if ! cli -c "app chart_release update chart_release=\"$app_name\" values={\"global\": {\"stopAll\": false}}" > /dev/null 2>&1; then
        #     return 1
        # fi
        abort_job "$app_name"
        # job_id=$(midclt call chart.release.scale "$app_name" '{"replica_count": '"$replica_count"'}') || return 1
        # sleep 5
        # midclt call core.job_abort "$job_id" > /dev/null 2>&1
    elif [[ $output == *"${app_name},stopAll-off"* ]]; then
        job_id=$(midclt call chart.release.scale "$app_name" '{"replica_count": '"$replica_count"'}') || return 1
        sleep 5
        midclt call core.job_abort "$job_id" > /dev/null 2>&1
    else
        if ! cli -c 'app chart_release scale release_name='\""$app_name"\"\ 'scale_options={"replica_count": '"$replica_count}" > /dev/null 2>&1; then
            return 1
        fi
    fi
    return 0
}