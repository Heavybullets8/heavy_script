#!/bin/bash

start_app(){
    local app_name=$1
    local replica_count=$2

    # Check if app is a cnpg instance, or an operator instance
    output=$(check_filtered_apps "$app_name")
    if echo "$output" | grep -q "${app_name},stopAll-on"; then
        if ! cli -c 'app chart_release scale release_name='\""$app_name"\"\ 'scale_options={"replica_count": '"$replica_count}" > /dev/null; then
            return 1
        fi
        if ! cli -c "app chart_release update chart_release=\"$app_name\" values={\"global\": {\"stopAll\": false}}" > /dev/null; then
            return 1
        fi
    else
        if ! cli -c 'app chart_release scale release_name='\""$app_name"\"\ 'scale_options={"replica_count": '"$replica_count}" > /dev/null; then
            return 1
        fi
    fi
    return 0
}