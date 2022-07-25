#!/bin/bash


update_apps(){
# Replace with line below after testing
# cli -m csv -c 'app chart_release query name,update_available,human_version,human_latest_version,container_images_update_available,status' | tr -d " \t\r" | grep -E ",true($|,)" | sort
mapfile -t array < <(cli -m csv -c 'app chart_release query name,update_available,human_version,human_latest_version,container_images_update_available,status' | grep -E ",true(,|\b)" | sort)
[[ -z $array ]] && echo -e "\nThere are no updates available" && return 0 || echo -e "\n${#array[@]} update(s) available"
[[ -z $timeout ]] && echo -e "\nDefault Timeout: 500" && timeout=500 || echo -e "\nCustom Timeout: $timeout"
[[ "$timeout" -le 120 ]] && echo "Warning: Your timeout is set low and may lead to premature rollbacks or skips"
for i in "${array[@]}"
do
    app_name=$(echo "$i" | awk -F ',' '{print $1}') #print out first catagory, name.
    old_app_ver=$(echo "$i" | awk -F ',' '{print $4}' | awk -F '_' '{print $1}' | awk -F '.' '{print $1}') #previous/current Application MAJOR Version
    new_app_ver=$(echo "$i" | awk -F ',' '{print $5}' | awk -F '_' '{print $1}' | awk -F '.' '{print $1}') #new Application MAJOR Version
    old_chart_ver=$(echo "$i" | awk -F ',' '{print $4}' | awk -F '_' '{print $2}' | awk -F '.' '{print $1}') # Old Chart MAJOR version
    new_chart_ver=$(echo "$i" | awk -F ',' '{print $5}' | awk -F '_' '{print $2}' | awk -F '.' '{print $1}') # New Chart MAJOR version
    status=$(echo "$i" | awk -F ',' '{print $2}') #status of the app: STOPPED / DEPLOYING / ACTIVE
    startstatus=$status
    diff_app=$(diff <(echo "$old_app_ver") <(echo "$new_app_ver")) #caluclating difference in major app versions
    diff_chart=$(diff <(echo "$old_chart_ver") <(echo "$new_chart_ver")) #caluclating difference in Chart versions
    old_full_ver=$(echo "$i" | awk -F ',' '{print $4}') #Upgraded From
    new_full_ver=$(echo "$i" | awk -F ',' '{print $5}') #Upraded To
    rollback_version=$(echo "$i" | awk -F ',' '{print $4}' | awk -F '_' '{print $2}')
    printf '%s\0' "${ignore[@]}" | grep -iFxqz "${app_name}" && echo -e "\n$app_name\nIgnored, skipping" && continue #If application is on ignore list, skip
    if [[ "$diff_app" == "$diff_chart" || "$update_all_apps" == "true" ]]; then #continue to update
        if [[ $stop_before_update == "true" ]]; then # Check to see if user is using -S or not
            if [[ "$status" ==  "STOPPED" ]]; then # if status is already stopped, skip while loop
                echo -e "\n$app_name"
                [[ "$verbose" == "true" ]] && echo "Updating.."
                cli -c 'app chart_release upgrade release_name=''"'"$app_name"'"' &> /dev/null && echo -e "Updated\n$old_full_ver\n$new_full_ver" && after_update_actions || echo "FAILED"
                continue
            else # if status was not STOPPED, stop the app prior to updating
                echo -e "\n$app_name"
                [[ "$verbose" == "true" ]] && echo "Stopping prior to update.."
                midclt call chart.release.scale "$app_name" '{"replica_count": 0}' &> /dev/null && SECONDS=0 || echo -e "FAILED"
                while [[ "$status" !=  "STOPPED" ]]
                do
                    status=$(cli -m csv -c 'app chart_release query name,update_available,human_version,human_latest_version,status' | grep "^$app_name," | awk -F ',' '{print $2}')
                    if [[ "$status"  ==  "STOPPED" ]]; then
                        echo "Stopped"
                        [[ "$verbose" == "true" ]] && echo "Updating.."
                        cli -c 'app chart_release upgrade release_name=''"'"$app_name"'"' &> /dev/null && echo -e "Updated\n$old_full_ver\n$new_full_ver" && after_update_actions || echo "Failed to update"
                        break
                    elif [[ "$SECONDS" -ge "$timeout" ]]; then
                        echo "Error: Run Time($SECONDS) has exceeded Timeout($timeout)"
                        break
                    elif [[ "$status" !=  "STOPPED" ]]; then
                        [[ "$verbose" == "true" ]] && echo "Waiting $((timeout-SECONDS)) more seconds for $app_name to be STOPPED"
                        sleep 10
                        continue
                    fi
                done
            fi
        else #user must not be using -S, just update
            echo -e "\n$app_name"
            [[ "$verbose" == "true" ]] && echo "Updating.."
            cli -c 'app chart_release upgrade release_name=''"'"$app_name"'"' &> /dev/null && echo -e "Updated\n$old_full_ver\n$new_full_ver" && after_update_actions || echo "FAILED"
        fi
    else
        echo -e "\n$app_name\nMajor Release, update manually"
        continue
    fi
done
}
export -f update_apps


after_update_actions(){
SECONDS=0
count=0
if [[ $rollback == "true" ]]; then
    while true
    do
        (( count++ ))
        status=$(cli -m csv -c 'app chart_release query name,update_available,human_version,human_latest_version,status' | grep "^$app_name," | awk -F ',' '{print $2}')
        if [[ "$status"  ==  "ACTIVE" && "$startstatus"  ==  "STOPPED" ]]; then
            [[ "$verbose" == "true" ]] && echo "Returing to STOPPED state.."
            midclt call chart.release.scale "$app_name" '{"replica_count": 0}' &> /dev/null && echo "Stopped"|| echo "FAILED"
            break
        elif [[ "$SECONDS" -ge "$timeout" && "$status"  ==  "DEPLOYING" && "$failed" != "true" ]]; then
            echo -e "Error: Run Time($SECONDS) for $app_name has exceeded Timeout($timeout)\nIf this is a slow starting application, set a higher timeout with -t\nIf this applicaion is always DEPLOYING, you can disable all probes under the Healthcheck Probes Liveness section in the edit configuration\nReverting update.."
            midclt call chart.release.rollback "$app_name" "{\"item_version\": \"$rollback_version\"}" &> /dev/null
            [[ "$startstatus"  ==  "STOPPED" ]] && failed="true" && after_update_actions && unset failed #run back after_update_actions function if the app was stopped prior to update
            break
        elif [[ "$SECONDS" -ge "$timeout" && "$status"  ==  "DEPLOYING" && "$failed" == "true" ]]; then
            echo -e "Error: Run Time($SECONDS) for $app_name has exceeded Timeout($timeout)\nThe application failed to be ACTIVE even after a rollback,\nManual intervention is required\nAbandoning"
            break
        elif [[ "$status"  ==  "STOPPED" ]]; then
            [[ "$count" -le 1 && "$verbose" == "true"  ]] && echo "Verifying Stopped.." && sleep 15 && continue #if reports stopped on FIRST time through loop, double check
            [[ "$count" -le 1  && -z "$verbose" ]] && sleep 15 && continue #if reports stopped on FIRST time through loop, double check
            echo "Stopped" && break #if reports stopped any time after the first loop, assume its extermal services.
        elif [[ "$status"  ==  "ACTIVE" ]]; then
            [[ "$count" -le 1 && "$verbose" == "true"  ]] && echo "Verifying Active.." && sleep 15 && continue #if reports active on FIRST time through loop, double check
            [[ "$count" -le 1  && -z "$verbose" ]] && sleep 15 && continue #if reports active on FIRST time through loop, double check
            echo "Active" && break #if reports active any time after the first loop, assume actually active.
        else
            [[ "$verbose" == "true" ]] && echo "Waiting $((timeout-SECONDS)) more seconds for $app_name to be ACTIVE"
            sleep 15
            continue
        fi
    done
else
    if [[  "$startstatus"  ==  "STOPPED"  ]]; then
        while true #using a constant while loop, then breaking out of the loop with break commands below.
        do
            (( count++ ))
            status=$(cli -m csv -c 'app chart_release query name,update_available,human_version,human_latest_version,status' | grep "^$app_name," | awk -F ',' '{print $2}')
            if [[ "$status"  ==  "STOPPED" ]]; then
                [[ "$count" -le 1 && "$verbose" == "true"  ]] && echo "Verifying Stopped.." && sleep 15 && continue #if reports stopped on FIRST time through loop, double check
                [[ "$count" -le 1  && -z "$verbose" ]] && sleep 15 && continue #if reports stopped on FIRST time through loop, double check
                echo "Stopped" && break #assume actually stopped anytime AFTER the first loop
                break
            elif [[ "$status"  ==  "ACTIVE" ]]; then
                [[ "$count" -le 1 && "$verbose" == "true"  ]] && echo "Verifying Active.." && sleep 15 && continue #if reports active on FIRST time through loop, double check
                [[ "$count" -le 1  && -z "$verbose" ]] && sleep 15 && continue #if reports active on FIRST time through loop, double check
                [[ "$verbose" == "true" ]] && echo "Returing to STOPPED state.."
                midclt call chart.release.scale "$app_name" '{"replica_count": 0}' &> /dev/null && echo "Stopped"|| echo "FAILED"
                break
            elif [[ "$SECONDS" -ge "$timeout" ]]; then
                echo "Error: Run Time($SECONDS) has exceeded Timeout($timeout)"
                break
            else
                [[ "$verbose" == "true" ]] && echo "Waiting $((timeout-SECONDS)) more seconds for $app_name to be ACTIVE"
                sleep 10
                continue
            fi
        done
    fi
fi
}
export -f after_update_actions