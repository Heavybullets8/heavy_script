#!/bin/bash

abort_job(){
    local app_name=$1
    job_ids=""

    # shellcheck disable=SC2034
    for i in {1..60}; do
        job_ids=$(get_running_job_id "$app_name")

        if [[ -n "$job_ids" ]]; then
            while IFS= read -r job_id; do
                midclt call core.job_abort "$job_id" > /dev/null 2>&1
            done <<< "$job_ids"
            return 0
        fi

        sleep 1
    done
    return 1
}

wait_for_redeploy_methods(){
    local app_name=$1
    local methods=""
    
    # shellcheck disable=SC2034
    for i in {1..60}; do
        methods=$(get_running_methods "$app_name")
        
        if [[ "$methods" == *"chart.release.redeploy"* && "$methods" == *"chart.release.redeploy_internal"* ]]; then
            return 0
        fi
        
        sleep 1
    done
    return 1
}

get_running_methods(){
    local app_name=$1
    midclt call core.get_jobs | jq -r --arg app_name "$app_name" \
        '.[] | select( .time_finished == null and .state == "RUNNING" and (.arguments[0] == $app_name)) | .method'
}

get_running_job_id(){
    local app_name=$1
    midclt call core.get_jobs | jq -r --arg app_name "$app_name" \
        '.[] | select( .time_finished == null and .state == "RUNNING" and (.progress.description | test("Waiting for pods to be scaled to [0-9]+ replica\\(s\\)$")) and (.arguments[0] == $app_name and .method == "chart.release.scale") ) | .id'
}

check_mounted(){
    local app_name=$1

    if [[ -d /mnt/mounted_apps/"$app_name" ]]; then
        unmount_app_func "$app_name" > /dev/null 2>&1
    fi
}

start_app(){
    local app_name=$1
    local job_id

    #check if app is currently mounted
    check_mounted "$app_name"

    # Check if app is a cnpg instance, or an operator instance
    output=$(check_filtered_apps "$app_name")
    if [[ $output == *"${app_name},stopAll-on"* ]]; then
        if ! cli -c "app chart_release update chart_release=\"$app_name\" values={\"global\": {\"stopAll\": false}}" > /dev/null 2>&1; then
            return 1
        fi
        abort_job "$app_name"
        job_id=$(midclt call chart.release.redeploy_internal "$app_name") || return 1
        wait_for_redeploy_methods "$app_name"
        midclt call core.job_abort "$job_id" > /dev/null 2>&1
    elif [[ $output == *"${app_name},stopAll-off"* ]]; then
        job_id=$(midclt call chart.release.redeploy_internal "$app_name") || return 1
        wait_for_redeploy_methods "$app_name"
        midclt call core.job_abort "$job_id" > /dev/null 2>&1
    else
        if ! cli -c 'app chart_release redeploy release_name='\""$app_name"\" > /dev/null 2>&1; then
            return 1
        fi
    fi
    return 0
}
