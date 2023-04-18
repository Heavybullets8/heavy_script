#!/bin/bash

verify_active(){
    if [[ "$verbose" == true ]]; then
        echo_array+=("Verifying $status..")
    fi
    before_loop=$(head -n 1 all_app_status)
    current_loop=0
    until [[ "$status" != "ACTIVE" || $current_loop -gt 4 ]] 
    do
        update_status "$app_name"
        sleep 1
        if ! echo -e "$(head -n 1 all_app_status)" | grep -qs ^"$before_loop" ; then
            before_loop=$(head -n 1 all_app_status)
            ((current_loop++))
        fi
    done
}

update_status() {
    status=$(grep "^$app_name," all_app_status | awk -F ',' '{print $2}')
}

rollbacks_disabled(){
    echo_array+=("Error: Run Time($SECONDS) for $app_name has exceeded Timeout($timeout)")
    echo_array+=("If this is a slow starting application, set a higher timeout with -t")
    echo_array+=("If this applicaion is always DEPLOYING, you can disable all probes under the Healthcheck Probes Liveness section in the edit configuration")
    echo_array+=("Manual intervention is required\nStopping, then Abandoning")
}

handle_wait() {
    if [[ "$verbose" == true ]]; then
        echo_array+=("Waiting $((timeout-SECONDS)) more seconds for $app_name to be ACTIVE")
    fi
    sleep 5
}

handle_rollback() {
    echo_array+=("Error: Run Time($SECONDS) for $app_name has exceeded Timeout($timeout)")
    echo_array+=("If this is a slow starting application, set a higher timeout with -t")
    echo_array+=("If this applicaion is always DEPLOYING, you can disable all probes under the Healthcheck Probes Liveness section in the edit configuration")
    echo_array+=("Reverting update..")       
    if rollback_app ; then
        echo_array+=("Rolled Back")
    else
        echo_array+=("Error: Failed to rollback $app_name\nAbandoning")
        return 1
    fi                    
}

post_process(){
    local app_name=$1
    local startstatus=$2
    local new_full_ver=$3
    local rolled_back=false
    local status

    SECONDS=0

    update_status

    if [[ $status == "ACTIVE" ]] && ! grep -q "^$app_name,DEPLOYING" deploying 2>/dev/null; then
        verify_active
    fi

    while true
    do
        update_status

        if [[ "$status"  ==  "ACTIVE" ]]; then
            if [[ "$startstatus"  ==  "STOPPED" ]]; then
                update_stop_handler 'Returing to STOPPED state...'
            else
                echo_array+=("Active")
            fi
            break
        elif [[ "$SECONDS" -ge "$timeout" ]]; then
            echo "$app_name,$new_full_ver" >> failed
            if [[ $rollback == true ]]; then
                if [[ "$rolled_back" == false ]]; then
                    handle_rollback || break
                    rolled_back=true
                    SECONDS=0
                    continue
                else
                    update_stop_handler 'Stopping...'
                    break
                fi
            else
                rollbacks_disabled
                update_stop_handler 'Stopping...'
                break
            fi
        else
            handle_wait
        fi
    done

    echo_array
}
export -f post_process
