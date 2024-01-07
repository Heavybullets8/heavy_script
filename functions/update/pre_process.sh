#!/bin/bash


get_app_details() {
    local app_info=$1
    
    app_name=$(echo "$app_info" | awk -F ',' '{print $1}')
    startstatus=$(echo "$app_info" | awk -F ',' '{print $2}')
    old_full_ver=$(echo "$app_info" | awk -F ',' '{print $4}')
    new_full_ver=$(echo "$app_info" | awk -F ',' '{print $5}')
    rollback_version=$(echo "$app_info" | awk -F ',' '{print $4}' | awk -F '_' '{print $2}')

    echo "$app_name,$startstatus,$old_full_ver,$new_full_ver,$rollback_version"
}

should_start_app() {
    if [[ $stop_before_update == true && "$startstatus" != "STOPPED" ]]; then
        return 0 
    fi

    if [[ $stopAll == true && $startstatus == "ACTIVE" ]]; then
        return 0 
    fi

    return 1 
}

wait_for_deploying() {
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

update_app_function() {
    # Send app through update function
    [[ "$verbose" == true ]] && echo_array+=("Updating..")
    if ! update_app; then
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
    local replicas
    replicas=$(pull_replicas "$app_name")

    if [[ $replicas == "0" || $replicas == "null" ]]; then
        if [[ "$verbose" == true ]]; then
            echo_array+=("No replica data, skipping post processing")
        fi
        return 1
    fi
    return 0
}

pre_process() {
    local app_info=$1
    local app_details

    app_details=$(get_app_details "$app_info")
    IFS=',' read -ra app_vars <<<"$app_details"
    app_name="${app_vars[0]}"
    startstatus="${app_vars[1]}"
    old_full_ver="${app_vars[2]}"
    new_full_ver="${app_vars[3]}"
    rollback_version="${app_vars[4]}"
    
    operator=$(printf '%s\0' "${apps_with_status[@]}" | grep -iFxqz "${app_name},operator" && echo true || echo false)
    isStopped=$(printf '%s\0' "${apps_with_status[@]}" | grep -iFxqz "${app_name},isStopped-on" && echo true || echo false)
    stopAll=$(printf '%s\0' "${apps_with_status[@]}" | grep -iFxqz "${app_name},stopAll-on" && echo true || echo false)
    cnpg=$(printf '%s\0' "${apps_with_status[@]}" | grep -iFxqz "${app_name},cnpg" && echo true || echo false)
    
    export operator isStopped stopAll cnpg 

    echo_array+=("\n$app_name")

    if [[ "$startstatus" == "DEPLOYING" ]]; then
        if ! wait_for_deploying; then
            echo_array
            return
        fi
    fi

    if [[ $operator == false && $stop_before_update == true && "$startstatus" != "STOPPED" ]]; then
        if ! update_stop_handler 'Stopping prior to update..'; then
            echo_array
            return
        fi
    fi

    if ! update_app_function; then
        echo_array
        return
    fi

    if [[ "$startstatus" == "STOPPED" ]]; then
        echo_array+=("Stopped")
        echo_array
        return
    fi

    if should_start_app; then
        if ! start_app "$app_name"; then
            echo_array+=("Failed to start $app_name")
            echo_array
            return 1
        fi
    fi

    if [[ $rollback == true && $startstatus == "ACTIVE" ]]; then
        if ! check_replicas; then
            echo_array
            return
        fi

        if [[ "$old_full_ver" == "$new_full_ver" ]]; then 
            # image_update_restart disable for now, as it is most likely no longer needed.
            echo_array
            return
        fi

        post_process
    else
        echo_array
        return
    fi
}