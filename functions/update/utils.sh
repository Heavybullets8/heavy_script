#!/bin/bash


update_stop_handler(){
    local message="$1"

    if [[ "$verbose" == true ]]; then
        echo_array+=("$message")
    fi
    stop_app "update" "$app_name" "${timeout:-100}"
    result=$(handle_stop_code "$?")
    if [[ $? -eq 1 ]]; then
        echo_array+=("$result")
    else
        echo_array+=("$result")
    fi
    return
}

rollback_app() {
    # Attempt to rollback the app up to 3 times
    for (( count=1; count<=3; count++ )); do
        update_avail=$(grep "^$app_name," all_app_status | awk -F ',' '{print $3","$6}')
        
        # If update_avail is true, return 0 (no rollback needed)
        if [[ "$update_avail" == "true" ]]; then
            return 0
        elif timeout 250s cli -c "app chart_release rollback release_name=\"$app_name\" rollback_options={\"item_version\": \"$rollback_version\"}" &> /dev/null; then
            # If the rollback is successful, return 0
            return 0
        else
            # Upon failure, wait for status update before continuing
            before_loop=$(head -n 1 all_app_status)
            until [[ $(head -n 1 all_app_status) != "$before_loop" ]]; do
                sleep 1
            done
        fi
    done

    # If the app is still not rolled back after 3 attempts, return an error code
    return 1
}

handle_snapshot_error() {
    local error_message="$1"
    local snapshot_name

    snapshot_name=$(echo "$error_message" | grep "cannot create snapshot" | cut -d "'" -f 2)

    # Destroy the snapshot
    if zfs destroy "$snapshot_name"; then
        return 0
    else
        return 1
    fi
}
export -f handle_snapshot_error

process_update() {
    local output error_message
    local handled_snapshot_error=false
    local last_attempt="$1"

    while true; do
        if output=$(timeout 300s cli -c 'app chart_release upgrade release_name=''"'"$app_name"'"' 2>&1); then
            return 0
        elif [[ $output =~ "No update is available" ]]; then
            return 0
        elif [[ $output =~ "cannot create snapshot" && $handled_snapshot_error == false ]]; then
            handle_snapshot_error "$output"
            handled_snapshot_error=true
            continue
        elif [[ $output =~ "dump interrupted" ]]; then
            sleep 20
            return 1
        else
            if $last_attempt; then
                echo_array+=("Failed to update\nManual intervention may be required")
                if $verbose; then
                    error_message=$(echo "$output" | grep -Ev '^\[[0-9]+%\]')
                    echo_array+=("$error_message")
                fi
            fi
            return 1
        fi
    done
}

update_app() {
    local before_loop update_avail count 
    local last_attempt=false

    while true; do
        # Function to check update availability
        check_update_avail() {
            update_avail=$(grep "^$app_name," all_app_status | awk -F ',' '{print $3","$6}')
            [[ $update_avail =~ "true" ]]
        }

        # If updates are not available, return success
        if ! check_update_avail; then
            return 0
        fi

        # Try updating the app up to 3 times
        for (( count=1; count<=3; count++ )); do
            if [[ "$count" -ge 3 ]]; then
                last_attempt=true
            fi
            
            if process_update $last_attempt; then
                # If the update was successful, return 0
                return 0
            fi

            # Wait for status update before continuing
            before_loop=$(head -n 1 all_app_status)
            until [[ $(head -n 1 all_app_status) != "$before_loop" ]]; do
                sleep 1
            done

            # Check if updates are still available after waiting
            if ! check_update_avail; then
                return 0
            fi
        done

        # If the app was not successfully updated after 3 attempts, return an error code
        return 1
    done
}
export -f update_app

echo_array(){
    #Dump the echo_array, ensures all output is in a neat order. 
    for i in "${echo_array[@]}"
    do
        echo -e "$i"
    done
    final_check
}
export -f echo_array

final_check(){
    if [[ ! -e finished ]]; then
        touch finished
    fi
    echo "$app_name,finished" >> finished
}