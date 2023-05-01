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

update_app() {
    # Attempt to update the app until successful or no updates are available
    while true; do
        # Check if updates are available for the app
        update_avail=$(grep "^$app_name," all_app_status | awk -F ',' '{print $3","$6}')

        # If updates are available, try to update the app
        if [[ $update_avail =~ "true" ]]; then
            # Try updating the app up to 3 times
            for (( count=1; count<=3; count++ )); do
                if timeout 250s cli -c 'app chart_release upgrade release_name=''"'"$app_name"'"' &> /dev/null; then
                    # If the update was successful, return 0
                    return 0
                else
                    # Upon failure, wait for status update before continuing
                    before_loop=$(head -n 1 all_app_status)
                    until [[ $(head -n 1 all_app_status) != "$before_loop" ]]; do
                        sleep 1
                    done
                fi
            done
            # If the app was not successfully updated after 3 attempts, return an error code
            return 1
        elif [[ ! $update_avail =~ "true" ]]; then
            # If no updates are available, return 0 (success)
            return 0
        else
            # If the update availability is not clear, wait 3 seconds and check again
            sleep 3
        fi
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