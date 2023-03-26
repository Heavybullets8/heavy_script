#!/bin/bash


pre_process(){
    app_name=$(echo "${array[$index]}" | awk -F ',' '{print $1}') #print out first catagory, name.
    startstatus=$(echo "${array[$index]}" | awk -F ',' '{print $2}') #status of the app: STOPPED / DEPLOYING / ACTIVE
    old_full_ver=$(echo "${array[$index]}" | awk -F ',' '{print $4}') #Upgraded From
    new_full_ver=$(echo "${array[$index]}" | awk -F ',' '{print $5}') #Upraded To
    rollback_version=$(echo "${array[$index]}" | awk -F ',' '{print $4}' | awk -F '_' '{print $2}')

    echo_array+=("\n$app_name")

    # TODO: remove this after a while
    if [[ -e external_services ]]; then
        rm external_services
    fi

    # If application is deploying prior to updating, attempt to wait for it to finish
    if [[ "$startstatus"  ==  "DEPLOYING" ]]; then
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
    fi

    # If user is using -S, stop app prior to updating
    if [[ $stop_before_update == true && "$startstatus" !=  "STOPPED" ]]; then # Check to see if user is using -S or not
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
    fi

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

    # Pull the number of replicas for the app
    replicas=$(pull_replicas "$app_name")

    # If rollbacks are enabled, or startstatus is stopped
    if [[ $rollback == true || "$startstatus"  ==  "STOPPED" ]]; then
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
            post_process
        fi
    else
        echo_array
        return
    fi

}
export -f pre_process