#!/bin/bash


get_app_details() {
    local app_info=$1
    local app_name
    local startstatus
    local old_full_ver
    local new_full_ver
    local rollback_version

    app_name=$(echo "$app_info" | awk -F ',' '{print $1}')
    startstatus=$(echo "$app_info" | awk -F ',' '{print $2}')
    old_full_ver=$(echo "$app_info" | awk -F ',' '{print $4}')
    new_full_ver=$(echo "$app_info" | awk -F ',' '{print $5}')
    rollback_version=$(echo "$app_info" | awk -F ',' '{print $4}' | awk -F '_' '{print $2}')

    echo "$app_name,$startstatus,$old_full_ver,$new_full_ver,$rollback_version"
}

wait_for_deploying() {
    local app_name=$1
    local status

    # If application is deploying prior to updating, attempt to wait for it to finish
    SECONDS=0
    while [[ "$status"  ==  "DEPLOYING" ]]
    do
        status=$(grep "^$app_name," all_app_status | awk -F ',' '{print $2}')
        if [[ "$SECONDS" -ge "$timeout" ]]; then
            echo_array+=("Application is stuck Deploying, Skipping to avoid damage")
            return 1
        fi
        sleep 5
    done
    startstatus="$status"
    return 0
}

stop_app_before_update() {
    local app_name=$1
    local exit_status
    
    # If user is using -S, stop app prior to updating
    if [[ "$verbose" == true ]]; then
        echo_array+=("Stopping prior to update..")
    fi
    stop_app "update" "$app_name" "${timeout:-100}"
    result=$(handle_stop_code "$?")
    exit_status=$?
    if [[ $exit_status -eq 1 ]]; then
        echo_array+=("$result")
        return $exit_status
    else
        echo_array+=("$result")
    fi
    return 0
}


update_app_function() {
    local app_name=$1
    local old_full_ver=$2
    local new_full_ver=$3

    # Send app through update function
    [[ "$verbose" == true ]] && echo_array+=("Updating..")
    if ! update_app; then
        echo_array+=("Failed to update\nManual intervention may be required")
        return 1
    else
        if [[ $old_full_ver == "$new_full_ver" ]]; then
            echo_array+=("Updated Container Image")
        else
            echo_array+=("Updated\n$old_full_ver\n$new_full_ver")
        fi
        return 0
    fi
}

image_update_restart() {
    if [[ "$verbose" == true ]]; then
        echo_array+=("Restarting..")
    fi
    if ! restart_app; then
        echo_array+=("Error: Failed to restart $app_name")
    else
        echo_array+=("Restarted")
    fi
}

check_replicas() {
    local app_name=$1
    local replicas
    replicas=$(pull_replicas "$app_name")

    if [[ $replicas == "0" ]]; then
        if [[ "$verbose" == true ]]; then
            echo_array+=("Application has 0 replicas, skipping post processing")
        fi
        return 1
    elif [[ $replicas == "null" ]]; then
        echo_array+=("HeavyScript does not know how many replicas this app has, skipping post processing")
        echo_array+=("Please submit a bug report on github so this can be fixed")
        return 1
    fi
    return 0
}

pre_process() {
    local app_info=$1
    local app_details
    local app_name
    local startstatus
    local old_full_ver
    local new_full_ver
    local rollback_version

    app_details=$(get_app_details "$app_info")
    IFS=',' read -ra app_vars <<<"$app_details"
    app_name="${app_vars[0]}"
    startstatus="${app_vars[1]}"
    old_full_ver="${app_vars[2]}"
    new_full_ver="${app_vars[3]}"
    rollback_version="${app_vars[4]}"

    echo_array+=("\n$app_name")

    if [[ "$startstatus" == "DEPLOYING" ]]; then
        if ! wait_for_deploying "$app_name"; then
            echo_array
            return
        fi
    fi

    if [[ $stop_before_update == true && "$startstatus" != "STOPPED" ]]; then
        if ! stop_app_before_update "$app_name"; then
            echo_array
            return
        fi
    fi

    if ! update_app_function "$app_name" "$old_full_ver" "$new_full_ver"; then
        echo_array
        return
    fi

    if [[ $rollback == true || "$startstatus"  ==  "STOPPED" ]]; then
        if ! check_replicas "$app_name"; then
            echo_array
            return
        fi

        if [[ "$old_full_ver" == "$new_full_ver" ]]; then 
            image_update_restart
            echo_array
            return
        fi

        post_process "$app_name" "$startstatus" "$new_full_ver"
    else
        echo_array
        return
    fi
}