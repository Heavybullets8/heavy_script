#!/bin/bash


post_process(){
    SECONDS=0
    count=0

    while true
    do
        # If app reports ACTIVE right away, assume its a false positive and wait for it to change, or trust it after 5 updates to all_app_status
        status=$(grep "^$app_name," all_app_status | awk -F ',' '{print $2}')
        # If status shows up as Active or Stopped on the first check, verify that. Otherwise it may be a false report..
        if [[ $count -lt 1 && $status == "ACTIVE" && "$(grep "^$app_name," deploying 2>/dev/null | awk -F ',' '{print $2}')" != "DEPLOYING" ]]; then  
            if [[ "$verbose" == true ]]; then
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
                if [[ "$verbose" == true ]]; then
                    echo_array+=("Returing to STOPPED state..")
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
                break
            else
                echo_array+=("Active")
                break 
            fi
        elif [[ "$SECONDS" -ge "$timeout" ]]; then
            if [[ $rollback == true ]]; then
                if [[ "$failed" != true ]]; then
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
                    failed=true
                    SECONDS=0
                    count=0
                    continue #run back post_process function if the app was stopped prior to update
                else
                    echo_array+=("Error: Run Time($SECONDS) for $app_name has exceeded Timeout($timeout)")
                    echo_array+=("The application failed to be ACTIVE even after a rollback")
                    echo_array+=("Manual intervention is required\nStopping, then Abandoning")
                    stop_app "update" "$app_name" "${timeout:-100}"
                    result=$(handle_stop_code "$?")
                    if [[ $? -eq 1 ]]; then
                        echo_array+=("$result")
                        echo_array
                        return
                    else
                        echo_array+=("$result")
                    fi
                    break
                fi
            else
                echo "$app_name,$new_full_ver" >> failed
                echo_array+=("Error: Run Time($SECONDS) for $app_name has exceeded Timeout($timeout)")
                echo_array+=("If this is a slow starting application, set a higher timeout with -t")
                echo_array+=("If this applicaion is always DEPLOYING, you can disable all probes under the Healthcheck Probes Liveness section in the edit configuration")
                echo_array+=("Manual intervention is required\nStopping, then Abandoning")
                stop_app "update" "$app_name" "${timeout:-100}"
                result=$(handle_stop_code "$?")
                if [[ $? -eq 1 ]]; then
                    echo_array+=("$result")
                    echo_array
                    return
                else
                    echo_array+=("$result")
                fi
                break
            fi
        else
            if [[ "$verbose" == true ]]; then
                echo_array+=("Waiting $((timeout-SECONDS)) more seconds for $app_name to be ACTIVE")
            fi
            sleep 5
            continue
        fi
    done

    echo_array
}
export -f post_process