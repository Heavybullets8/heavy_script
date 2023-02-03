#!/bin/bash


commander(){
    mapfile -t array < <(cli -m csv -c 'app chart_release query name,update_available,human_version,human_latest_version,container_images_update_available,status' | 
                        tr -d " \t\r" | 
                        grep -E ",true($|,)" | 
                        sort)
    echo -e "🅄 🄿 🄳 🄰 🅃 🄴 🅂"

    if [[ -z ${array[*]} ]]; then
        echo "There are no updates available"
        echo -e "\n"
        return 0
    else
        echo "Update(s) Available: ${#array[@]}"
    fi

    echo "Asynchronous Updates: $update_limit"
    
    
    if [[ -z $timeout ]]; then
        echo "Default Timeout: 500" && timeout=500
    else
        echo "Custom Timeout: $timeout"
    fi

    if [[ "$timeout" -le 120 ]];then 
        echo "Warning: Your timeout is set low and may lead to premature rollbacks or skips"
    fi

    if [[ $ignore_image_update == "true" ]]; then
        echo "Image Updates: Disabled"
    else
        echo "Image Updates: Enabled"
    fi

    pool=$(cli -c 'app kubernetes config' | 
           grep -E "dataset\s\|" | 
           awk -F '|' '{print $3}' | 
           awk -F '/' '{print $1}' | 
           tr -d " \t\n\r")

    index=0
    for app in "${array[@]}"
    do
        app_name=$(echo "$app" | awk -F ',' '{print $1}') #print out first catagory, name.
        old_app_ver=$(echo "$app" | awk -F ',' '{print $4}' | awk -F '_' '{print $1}' | awk -F '.' '{print $1}') #previous/current Application MAJOR Version
        new_app_ver=$(echo "$app" | awk -F ',' '{print $5}' | awk -F '_' '{print $1}' | awk -F '.' '{print $1}') #new Application MAJOR Version
        old_chart_ver=$(echo "$app" | awk -F ',' '{print $4}' | awk -F '_' '{print $2}' | awk -F '.' '{print $1}') # Old Chart MAJOR version
        new_chart_ver=$(echo "$app" | awk -F ',' '{print $5}' | awk -F '_' '{print $2}' | awk -F '.' '{print $1}') # New Chart MAJOR version
        diff_app=$(diff <(echo "$old_app_ver") <(echo "$new_app_ver")) #caluclating difference in major app versions
        diff_chart=$(diff <(echo "$old_chart_ver") <(echo "$new_chart_ver")) #caluclating difference in Chart versions
        old_full_ver=$(echo "$app" | awk -F ',' '{print $4}') #Upgraded From
        new_full_ver=$(echo "$app" | awk -F ',' '{print $5}') #Upraded To

        #Skip application if its on ignore list
        if printf '%s\0' "${ignore[@]}" | grep -iFxqz "${app_name}" ; then
            echo -e "\n$app_name\nIgnored, skipping"
            unset "array[$index]"
        #Skip appliaction if major update and not ignoreing major versions
        elif [[ "$diff_app" != "$diff_chart" && $update_apps == "true" ]] ; then
            echo -e "\n$app_name\nMajor Release, update manually"
            unset "array[$index]"
        # Skip update if application previously failed on this exact update version
        elif  grep -qs "^$app_name," failed 2>/dev/null; then
            failed_ver=$(grep "^$app_name," failed | awk -F ',' '{print $2}')
            if [[ "$failed_ver" == "$new_full_ver" ]] ; then
                echo -e "\n$app_name\nSkipping previously failed version:\n$new_full_ver"
                unset "array[$index]"
            else 
                sed -i /"$app_name",/d failed
            fi
        #Skip Image updates if ignore image updates is set to true
        elif [[ $old_full_ver == "$new_full_ver" && $ignore_image_update == "true" ]]; then
            echo -e "\n$app_name\nImage update, skipping.."
            unset "array[$index]"
        fi
        ((index++))
    done
    array=("${array[@]}")

    if [[ ${#array[@]} == 0 ]]; then
        echo
        echo
        return
    fi


    index=0
    while_count=0
    rm deploying 2>/dev/null
    rm finished 2>/dev/null
    while [[ ${#processes[@]} != 0 || $(wc -l finished 2>/dev/null | awk '{ print $1 }') -lt "${#array[@]}" ]]
    do
        if while_status=$(cli -m csv -c 'app chart_release query name,update_available,human_version,human_latest_version,container_images_update_available,status' 2>/dev/null) ; then
            ((while_count++)) 
            if [[ -z $while_status ]]; then
                continue
            else
                echo -e "$while_count\n$while_status" > all_app_status
            fi
            mapfile -t deploying_check < <(grep ",DEPLOYING," all_app_status)
            for i in "${deploying_check[@]}"
            do
                if [[ ! -e deploying ]]; then
                    touch deploying
                fi
                app_name=$(echo "$i" | awk -F ',' '{print $1}')
                if ! grep -qs "$app_name,DEPLOYING" deploying; then
                    echo "$app_name,DEPLOYING" >> deploying
                fi
            done
        else
            echo "Middlewared timed out. Consider setting a lower number for async applications"
            continue
        fi
        for i in "${!processes[@]}"; do
            kill -0 "${processes[i]}" &> /dev/null || unset "processes[$i]"
        done
        processes=("${processes[@]}")
        if [[ $index -lt ${#array[@]} && "${#processes[@]}" -lt "$update_limit" ]]; then
            pre_process "${array[$index]}" &
            processes+=($!)
            ((index++))
        else 
            sleep 3
        fi
    done
    rm deploying 2>/dev/null
    rm finished 2>/dev/null
    echo
    echo
}
export -f commander


pre_process(){
    app_name=$(echo "${array[$index]}" | awk -F ',' '{print $1}') #print out first catagory, name.
    startstatus=$(echo "${array[$index]}" | awk -F ',' '{print $2}') #status of the app: STOPPED / DEPLOYING / ACTIVE
    old_full_ver=$(echo "${array[$index]}" | awk -F ',' '{print $4}') #Upgraded From
    new_full_ver=$(echo "${array[$index]}" | awk -F ',' '{print $5}') #Upraded To
    rollback_version=$(echo "${array[$index]}" | awk -F ',' '{print $4}' | awk -F '_' '{print $2}')


    # Check if app is external services, append outcome to external_services file
    if [[ ! -e external_services ]]; then
        touch external_services
    fi
    if ! grep -qs "^$app_name," external_services ; then 
        if ! grep -qs "/external-service" /mnt/"$pool"/ix-applications/releases/"$app_name"/charts/"$(find /mnt/"$pool"/ix-applications/releases/"$app_name"/charts/ -maxdepth 1 -type d -printf '%P\n' | sort -r | head -n 1)"/Chart.yaml; then
            echo "$app_name,false" >> external_services
        else
            echo "$app_name,true" >> external_services
        fi
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
    echo_array+=("\n$app_name")
    if [[ $stop_before_update == "true" && "$startstatus" !=  "STOPPED" ]]; then # Check to see if user is using -S or not
        if [[ "$verbose" == "true" ]]; then
            echo_array+=("Stopping prior to update..")
        fi
        if stop_app ; then
            echo_array+=("Stopped")
        else
            echo_array+=("Error: Failed to stop $app_name")
            echo_array
            return 1
        fi
    fi

    # Send app through update function
    [[ "$verbose" == "true" ]] && echo_array+=("Updating..")
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


    # If rollbacks are enabled, or startstatus is stopped
    if [[ $rollback == "true" || "$startstatus"  ==  "STOPPED" ]]; then
        # If app is external services, skip post processing
        if grep -qs "^$app_name,true" external_services; then 
            echo_array
            return
        elif [[ "$old_full_ver" == "$new_full_ver" ]]; then 
            # restart the app if it was a container image update.
            if [[ "$verbose" == "true" ]]; then
                echo_array+=("Restarting $app_name..")
            fi
            if ! restart_app; then
                echo_array+=("Failed to restart $app_name")
            else
                echo_array+=("Restarted $app_name")
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


restart_app(){
    dep_name=$(k3s kubectl -n ix-"$app_name" get deploy | sed -e '1d' -e 's/ .*//')
    if k3s kubectl -n ix-"$app_name" rollout restart deploy "$dep_name"; then
        return 0
    else
        return 1
    fi
}


post_process(){
    SECONDS=0
    count=0

    while true
    do
        # If app reports ACTIVE right away, assume its a false positive and wait for it to change, or trust it after 5 updates to all_app_status
        status=$(grep "^$app_name," all_app_status | awk -F ',' '{print $2}')
        # If status shows up as Active or Stopped on the first check, verify that. Otherwise it may be a false report..
        if [[ $count -lt 1 && $status == "ACTIVE" && "$(grep "^$app_name," deploying 2>/dev/null | awk -F ',' '{print $2}')" != "DEPLOYING" ]]; then  
            if [[ "$verbose" == "true" ]]; then
                echo_array+=("Verifying $status..")
            fi
            before_loop=$(head -n 1 all_app_status)
            current_loop=0
            # Wait for a specific change to app status, or 3 refreshes of the file to go by.
            until [[ "$status" != "ACTIVE" || $current_loop -gt 4 ]] 
            do
                status=$(grep "^$app_name," all_app_status | awk -F ',' '{print $2}')
                sleep 1
                if ! echo -e "$(head -n 1 all_app_status)" | grep -qs ^"$before_loop" ; then
                    before_loop=$(head -n 1 all_app_status)
                    ((current_loop++))
                fi
            done
        fi
        (( count++ ))

        if [[ "$status"  ==  "ACTIVE" ]]; then
            if [[ "$startstatus"  ==  "STOPPED" ]]; then
                if [[ "$verbose" == "true" ]]; then
                    echo_array+=("Returing to STOPPED state..")
                fi
                if stop_app ; then
                    echo_array+=("Stopped")
                else
                    echo_array+=("Error: Failed to stop $app_name")
                    echo_array
                    return 1
                fi
                break
            else
                echo_array+=("Active")
                break 
            fi
        elif [[ "$SECONDS" -ge "$timeout" ]]; then
            if [[ $rollback == "true" ]]; then
                if [[ "$failed" != "true" ]]; then
                    echo "$app_name,$new_full_ver" >> failed
                    echo_array+=("Error: Run Time($SECONDS) for $app_name has exceeded Timeout($timeout)")
                    echo_array+=("If this is a slow starting application, set a higher timeout with -t")
                    echo_array+=("If this applicaion is always DEPLOYING, you can disable all probes under the Healthcheck Probes Liveness section in the edit configuration")
                    echo_array+=("Reverting update..")       
                    if rollback_app ; then
                        echo_array+=("Rolled Back")
                    else
                        echo_array+=("Error: Failed to rollback $app_name\nAbandoning")
                        echo_array
                        return 1
                    fi                    
                    failed="true"
                    SECONDS=0
                    count=0
                    continue #run back post_process function if the app was stopped prior to update
                else
                    echo_array+=("Error: Run Time($SECONDS) for $app_name has exceeded Timeout($timeout)")
                    echo_array+=("The application failed to be ACTIVE even after a rollback")
                    echo_array+=("Manual intervention is required\nStopping, then Abandoning")
                    if stop_app ; then
                        echo_array+=("Stopped")
                    else
                        echo_array+=("Error: Failed to stop $app_name")
                        echo_array
                        return 1
                    fi
                    break
                fi
            else
                echo "$app_name,$new_full_ver" >> failed
                echo_array+=("Error: Run Time($SECONDS) for $app_name has exceeded Timeout($timeout)")
                echo_array+=("If this is a slow starting application, set a higher timeout with -t")
                echo_array+=("If this applicaion is always DEPLOYING, you can disable all probes under the Healthcheck Probes Liveness section in the edit configuration")
                echo_array+=("Manual intervention is required\nStopping, then Abandoning")
                if stop_app ; then
                    echo_array+=("Stopped")
                else
                    echo_array+=("Error: Failed to stop $app_name")
                    echo_array
                    return 1
                fi
                break
            fi
        else
            if [[ "$verbose" == "true" ]]; then
                echo_array+=("Waiting $((timeout-SECONDS)) more seconds for $app_name to be ACTIVE")
            fi
            sleep 5
            continue
        fi
    done

    echo_array
}
export -f post_process



rollback_app() {
    app_update_avail=$(grep "^$app_name," all_app_status | awk -F ',' '{print $3}')

    # Continuously try to rollback the app until it is successful or the maximum number of tries is reached
    for (( count=0; count<3; count++ )); do
        if [[ "$app_update_avail" == "true" ]]; then
            return 0
        elif cli -c "app chart_release rollback release_name=\"$app_name\" rollback_options={\"item_version\": \"$rollback_version\"}" &> /dev/null; then
            return 0
        else
            # Upon failure, wait for status update before continuing
            before_loop=$(head -n 1 all_app_status)
            until [[ $(head -n 1 all_app_status) != "$before_loop" ]] 
            do
                sleep 1
            done
        fi
    done

    # If the app is still not rolled back, return an error code
    if [[ "$app_update_avail" != "true" ]]; then
        return 1
    fi
}



update_app() {
    # Loop until the app has been successfully updated or no updates are available
    while true; do
        # Check if updates are available for the app
        update_avail=$(grep "^$app_name," all_app_status | awk -F ',' '{print $3","$6}')

        # If updates are available, try to update the app
        if [[ $update_avail =~ "true" ]]; then
            # Try updating the app up to 3 times
            for (( count=0; count<3; count++ )); do
                if cli -c 'app chart_release upgrade release_name=''"'"$app_name"'"' &> /dev/null; then
                    # If the update was successful, break out of the loop
                    return 0
                else
                    # Upon failure, wait for status update before continuing
                    before_loop=$(head -n 1 all_app_status)
                    until [[ $(head -n 1 all_app_status) != "$before_loop" ]]; do
                        sleep 1
                    done
                fi
            done

            # If the app was not successfully updated, return an error code
            if [[ $count -eq 3 ]]; then
                return 1
            fi

            # Break out of the loop if the update was successful
            break
        elif [[ ! $update_avail =~ "true" ]]; then
            # If no updates are available, break out of the loop
            break
        else
            # If the update availability is not clear, wait 3 seconds and check again
            sleep 3
        fi
    done
}
export -f update_app



stop_app() {
    # Continuously try to stop the app until it is stopped or the maximum number of tries is reached
    for (( count=0; count<3; count++ )); do
        status=$(grep "^$app_name," all_app_status | awk -F ',' '{print $2}')
        if [[ "$status" == "STOPPED" ]]; then
            return 0
        elif cli -c 'app chart_release scale release_name='\""$app_name"\"\ 'scale_options={"replica_count": 0}' &> /dev/null; then
            return 0
        else
            # Upon failure, wait for status update before continuing
            before_loop=$(head -n 1 all_app_status)
            until [[ $(head -n 1 all_app_status) != "$before_loop" ]]; do
                sleep 1
            done
        fi
    done

    # If the app is still not stopped, return an error code
    if [[ "$status" != "STOPPED" ]]; then
        return 1
    fi
}
export -f stop_app


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