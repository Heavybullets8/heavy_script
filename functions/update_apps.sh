#!/bin/bash


commander(){
mapfile -t array < <(cli -m csv -c 'app chart_release query name,update_available,human_version,human_latest_version,container_images_update_available,status' | tr -d " \t\r" | grep -E ",true($|,)" | sort)
echo -e "\n\nAplication Update Output"
echo "------------------------"
[[ -z ${array[*]} ]] && echo "There are no updates available" && return 0 || echo "${#array[@]} update(s) available"
[[ -z $timeout ]] && echo "Default Timeout: 500" && timeout=500 || echo "Custom Timeout: $timeout"
[[ "$timeout" -le 120 ]] && echo "Warning: Your timeout is set low and may lead to premature rollbacks or skips"
echo "Asynchronous Updates: $update_limit"

touch temp.txt
it=0
while true
do
    while_status=$(cli -m csv -c 'app chart_release query name,update_available,human_version,human_latest_version,status') 
    echo "$while_status" > temp.txt
    proc_count=${#processes[@]}
    count=0
    for proc in "${processes[@]}"
    do
        kill -0 "$proc" &> /dev/null || { unset "processes[$count]"; ((proc_count--)); }
        ((count++)) 
    done
    if [[ "$proc_count" -ge "$update_limit" ]]; then
        sleep 3
    elif [[ $it -lt ${#array[@]} ]]; then
        update_apps "${array[$it]}" &
        processes+=($!)
        ((it++))
    elif [[ $proc_count != 0 ]]; then # Wait for all processes to finish
        sleep 3
    else # All processes must be completed, break out of loop
        # Unessesary for loop. since processes have to be completed before getting to this point, it is unlikely we would ever have to wait on processes.. Will test more.
        # for proc in "${processes[@]}"; do
        #     wait "$proc"
        # done
        break
    fi
done
rm temp.txt

}
export -f commander


update_apps(){
app_name=$(echo "${array[$it]}" | awk -F ',' '{print $1}') #print out first catagory, name.
printf '%s\0' "${ignore[@]}" | grep -iFxqz "${app_name}" && echo -e "\n$app_name\nIgnored, skipping" && return 0 #If application is on ignore list, skip
old_app_ver=$(echo "${array[$it]}" | awk -F ',' '{print $4}' | awk -F '_' '{print $1}' | awk -F '.' '{print $1}') #previous/current Application MAJOR Version
new_app_ver=$(echo "${array[$it]}" | awk -F ',' '{print $5}' | awk -F '_' '{print $1}' | awk -F '.' '{print $1}') #new Application MAJOR Version
old_chart_ver=$(echo "${array[$it]}" | awk -F ',' '{print $4}' | awk -F '_' '{print $2}' | awk -F '.' '{print $1}') # Old Chart MAJOR version
new_chart_ver=$(echo "${array[$it]}" | awk -F ',' '{print $5}' | awk -F '_' '{print $2}' | awk -F '.' '{print $1}') # New Chart MAJOR version
status=$(echo "${array[$it]}" | awk -F ',' '{print $2}') #status of the app: STOPPED / DEPLOYING / ACTIVE
startstatus=$status
diff_app=$(diff <(echo "$old_app_ver") <(echo "$new_app_ver")) #caluclating difference in major app versions
diff_chart=$(diff <(echo "$old_chart_ver") <(echo "$new_chart_ver")) #caluclating difference in Chart versions
old_full_ver=$(echo "${array[$it]}" | awk -F ',' '{print $4}') #Upgraded From
new_full_ver=$(echo "${array[$it]}" | awk -F ',' '{print $5}') #Upraded To
rollback_version=$(echo "${array[$it]}" | awk -F ',' '{print $4}' | awk -F '_' '{print $2}')
    if [[ "$diff_app" == "$diff_chart" || "$update_all_apps" == "true" ]]; then #continue to update
        if [[ $stop_before_update == "true" ]]; then # Check to see if user is using -S or not
            if [[ "$status" ==  "STOPPED" ]]; then # if status is already stopped, skip while loop
                echo_array+=("\n$app_name")
                [[ "$verbose" == "true" ]] && echo_array+=("Updating..")
                cli -c 'app chart_release upgrade release_name=''"'"$app_name"'"' &> /dev/null && echo_array+=("Updated\n$old_full_ver\n$new_full_ver") && after_update_actions || echo_array+=("FAILED")
                return 0
            else # if status was not STOPPED, stop the app prior to updating
                echo_array+=("\n$app_name")
                [[ "$verbose" == "true" ]] && echo_array+=("Stopping prior to update..")
                midclt call chart.release.scale "$app_name" '{"replica_count": 0}' &> /dev/null && SECONDS=0 || echo_array+=("FAILED")
                while [[ "$status" !=  "STOPPED" ]]
                do
                    status=$( grep "^$app_name," temp.txt | awk -F ',' '{print $2}')
                    if [[ "$status"  ==  "STOPPED" ]]; then
                        echo_array+=("Stopped")
                        [[ "$verbose" == "true" ]] && echo_array+=("Updating..")
                        cli -c 'app chart_release upgrade release_name=''"'"$app_name"'"' &> /dev/null && echo_array+=("Updated\n$old_full_ver\n$new_full_ver") && after_update_actions || echo_array+=("Failed to update")
                        break
                    elif [[ "$SECONDS" -ge "$timeout" ]]; then
                        echo_array+=("Error: Run Time($SECONDS) has exceeded Timeout($timeout)")
                        break
                    elif [[ "$status" !=  "STOPPED" ]]; then
                        [[ "$verbose" == "true" ]] && echo_array+=("Waiting $((timeout-SECONDS)) more seconds for $app_name to be STOPPED")
                        sleep 10
                    fi
                done
            fi
        else #user must not be using -S, just update
            echo_array+=("\n$app_name")
            [[ "$verbose" == "true" ]] && echo_array+=("Updating..")
            cli -c 'app chart_release upgrade release_name=''"'"$app_name"'"' &> /dev/null && echo_array+=("Updated\n$old_full_ver\n$new_full_ver") && after_update_actions || echo_array+=("FAILED")
        fi
    else
        echo_array+=("\n$app_name\nMajor Release, update manually")
        return 0
    fi
}
export -f update_apps


after_update_actions(){
SECONDS=0
count=0
if [[ $rollback == "true" ]]; then
    while true
    do
        (( count++ ))
        status=$( grep "^$app_name," temp.txt | awk -F ',' '{print $2}')
        if [[ "$status"  ==  "ACTIVE" && "$startstatus"  ==  "STOPPED" ]]; then
            [[ "$verbose" == "true" ]] && echo_array+=("Returing to STOPPED state..")
            midclt call chart.release.scale "$app_name" '{"replica_count": 0}' &> /dev/null && echo_array+=("Stopped")|| echo_array+=("FAILED")
            break
        elif [[ "$SECONDS" -ge "$timeout" && "$status"  ==  "DEPLOYING" && "$failed" != "true" ]]; then
            echo_array+=("Error: Run Time($SECONDS) for $app_name has exceeded Timeout($timeout)\nIf this is a slow starting application, set a higher timeout with -t\nIf this applicaion is always DEPLOYING, you can disable all probes under the Healthcheck Probes Liveness section in the edit configuration\nReverting update..")
            midclt call chart.release.rollback "$app_name" "{\"item_version\": \"$rollback_version\"}" &> /dev/null
            [[ "$startstatus"  ==  "STOPPED" ]] && failed="true" && after_update_actions && unset failed #run back after_update_actions function if the app was stopped prior to update
            break
        elif [[ "$SECONDS" -ge "$timeout" && "$status"  ==  "DEPLOYING" && "$failed" == "true" ]]; then
            echo_array+=("Error: Run Time($SECONDS) for $app_name has exceeded Timeout($timeout)\nThe application failed to be ACTIVE even after a rollback,\nManual intervention is required\nAbandoning")
            break
        elif [[ "$status"  ==  "STOPPED" ]]; then
            [[ "$count" -le 1 && "$verbose" == "true"  ]] && echo_array+=("Verifying Stopped..") && sleep 15 && continue #if reports stopped on FIRST time through loop, double check
            [[ "$count" -le 1  && -z "$verbose" ]] && sleep 15 && continue #if reports stopped on FIRST time through loop, double check
            echo_array+=("Stopped") && break #if reports stopped any time after the first loop, assume its extermal services.
        elif [[ "$status"  ==  "ACTIVE" ]]; then
            [[ "$count" -le 1 && "$verbose" == "true"  ]] && echo_array+=("Verifying Active..") && sleep 15 && continue #if reports active on FIRST time through loop, double check
            [[ "$count" -le 1  && -z "$verbose" ]] && sleep 15 && continue #if reports active on FIRST time through loop, double check
            echo_array+=("Active") && break #if reports active any time after the first loop, assume actually active.
        else
            [[ "$verbose" == "true" ]] && echo_array+=("Waiting $((timeout-SECONDS)) more seconds for $app_name to be ACTIVE")
            sleep 15
            continue
        fi
    done
else
    if [[  "$startstatus"  ==  "STOPPED"  ]]; then
        while true #using a constant while loop, then breaking out of the loop with break commands below.
        do
            (( count++ ))
            status=$( grep "^$app_name," temp.txt | awk -F ',' '{print $2}')
            if [[ "$status"  ==  "STOPPED" ]]; then
                [[ "$count" -le 1 && "$verbose" == "true"  ]] && echo_array+=("Verifying Stopped..") && sleep 15 && continue #if reports stopped on FIRST time through loop, double check
                [[ "$count" -le 1  && -z "$verbose" ]] && sleep 15 && continue #if reports stopped on FIRST time through loop, double check
                echo_array+=("Stopped") && break #assume actually stopped anytime AFTER the first loop
                break
            elif [[ "$status"  ==  "ACTIVE" ]]; then
                [[ "$count" -le 1 && "$verbose" == "true"  ]] && echo_array+=("Verifying Active..") && sleep 15 && continue #if reports active on FIRST time through loop, double check
                [[ "$count" -le 1  && -z "$verbose" ]] && sleep 15 && continue #if reports active on FIRST time through loop, double check
                [[ "$verbose" == "true" ]] && echo_array+=("Returing to STOPPED state..")
                midclt call chart.release.scale "$app_name" '{"replica_count": 0}' &> /dev/null && echo_array+=("Stopped")|| echo_array+=("FAILED")
                break
            elif [[ "$SECONDS" -ge "$timeout" ]]; then
                echo_array+=("Error: Run Time($SECONDS) has exceeded Timeout($timeout)")
                break
            else
                [[ "$verbose" == "true" ]] && echo_array+=("Waiting $((timeout-SECONDS)) more seconds for $app_name to be ACTIVE")
                sleep 10
                continue
            fi
        done
    fi
fi

#Dump the echo_array, ensures all output is in a neat order. 
for i in "${echo_array[@]}"
do
    echo -e "$i"
done


}
export -f after_update_actions