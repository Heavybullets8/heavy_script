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

    # If application is deploying prior to updating, attempt to wait for it to finish
    SECONDS=0
    while [[ "$status"  ==  "DEPLOYING" ]]
    do
        status=$(grep "^$app_name," all_app_status | awk -F ',' '{print $2}')
        if [[ "$SECONDS" -ge "$timeout" ]]; then
            echo_array+=("Application is stuck Deploying, Skipping to avoid damage")
            echo_array
            return
        fi
        sleep 5
    done
    startstatus="$status"
}

stop_app_before_update() {
    local app_name=$1
    
    # If user is using -S, stop app prior to updating
    if [[ "$verbose" == true ]]; then
        echo_array+=("Stopping prior to update..")
    fi
    stop_app "update" "$app_name" "${timeout:-100}"
    result=$(handle_stop_code "$?")
    if [[ $? -eq 1 ]]; then
        echo_array+=("$result")
        echo_array
        return
    else
        echo_array+=("$result")
    fi

}

update_app_function() {
    local app_name=$1
    local old_full_ver=$2
    local new_full_ver=$3

    # Send app through update function
    [[ "$verbose" == true ]] && echo_array+=("Updating..")
    if update_app; then
        if [[ $old_full_ver == "$new_full_ver" ]]; then
            echo_array+=("Updated Container Image")
        else
            echo_array+=("Updated\n$old_full_ver\n$new_full_ver")
        fi
    else
        echo_array+=("Failed to update\nManual intervention may be required")
        echo_array
        return
    fi
}

handle_rollbacks_or_stopped() {
    local app_name=$1
    local startstatus=$2
    local old_full_ver=$3
    local new_full_ver=$4
    local replicas
    replicas=$(pull_replicas "$app_name")

    # If app is external services, skip post processing
    if [[ $replicas == "0" ]]; then
        if [[ "$verbose" == true ]]; then
            echo_array+=("Application has 0 replicas, skipping post processing")
        fi
        echo_array
        return
    elif [[ $replicas == "null" ]]; then
        echo_array+=("HeavyScript does not know how many replicas this app has, skipping post processing")
        echo_array+=("Please submit a bug report on github so this can be fixed")
        echo_array
        return
    elif [[ "$old_full_ver" == "$new_full_ver" ]]; then 
        # restart the app if it was a container image update.
        if [[ "$verbose" == true ]]; then
            echo_array+=("Restarting..")
        fi
        if ! restart_app; then
            echo_array+=("Error: Failed to restart $app_name")
        else
            echo_array+=("Restarted")
        fi
        echo_array
        return
    else
        post_process "$app_name" "$startstatus" "$new_full_ver"
    fi
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
        wait_for_deploying  "$app_name" "$startstatus"
    fi

    if [[ $stop_before_update == true && "$startstatus" != "STOPPED" ]]; then
        stop_app_before_update "$app_name"
    fi

    update_app_function "$app_name" "$old_full_ver" "$new_full_ver"

    if [[ $rollback == true || "$startstatus"  ==  "STOPPED" ]]; then
        handle_rollbacks_or_stopped "$app_name" "$startstatus" "$old_full_ver" "$new_full_ver"
    else
        echo_array
        return
    fi
}