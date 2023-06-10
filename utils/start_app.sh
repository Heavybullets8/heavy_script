#!/bin/bash

abort_job(){
    # Get the job ID
    job_id=$(get_running_job_id "$app_name")

    # Abort the job if found
    if [ -n "$job_id" ]; then
        echo "Aborting job with id: $job_id"
        midclt call core.job_abort "$job_id"
    else
        echo "No matching job found."
    fi
}

get_running_job_id(){
    local app_name=$1
    midclt call core.get_jobs | jq -r --arg app_name "$app_name" \
        '.[] | select( .time_finished == null and .state == "RUNNING" and (.progress.description | test("Waiting for pods to be scaled to [0-9]+ replica\\(s\\)$")) and (.arguments[0] == $app_name and .method == "chart.release.scale") ) | .id'
}

start_app(){
    local app_name=$1
    local replica_count=$2
    local job_id

    # Check if app is a cnpg instance, or an operator instance
    output=$(check_filtered_apps "$app_name")
    if [[ $output == *"${app_name},stopAll-on"* ]]; then
        if ! cli -c "app chart_release update chart_release=\"$app_name\" values={\"global\": {\"stopAll\": false}}" > /dev/null; then
            return 1
        fi
        abort_job "$app_name"
        job_id=$(midclt call chart.release.scale "$app_name" '{"replica_count": '"$replica_count"'}') || return 1
        sleep 5
        midclt call core.job_abort "$job_id"
    elif [[ $output == *"${app_name},stopAll-off"* ]]; then
        job_id=$(midclt call chart.release.scale "$app_name" '{"replica_count": '"$replica_count"'}') || return 1
        sleep 5
        midclt call core.job_abort "$job_id"
    else
        if ! cli -c 'app chart_release scale release_name='\""$app_name"\"\ 'scale_options={"replica_count": '"$replica_count}" > /dev/null; then
            return 1
        fi
    fi
    return 0
}