#!/bin/bash


commander(){
mapfile -t array < <(cli -m csv -c 'app chart_release query name,update_available,human_version,human_latest_version,container_images_update_available,status' | tr -d " \t\r" | grep -E ",true($|,)" | sort)
echo -e "🅄 🄿 🄳 🄰 🅃 🄴 🅂"
[[ -z ${array[*]} ]] && echo "There are no updates available" && echo -e "\n" && return 0 || echo "Update(s) Available: ${#array[@]}"
echo "Asynchronous Updates: $update_limit"
[[ -z $timeout ]] && echo "Default Timeout: 500" && timeout=500 || echo "Custom Timeout: $timeout"
[[ "$timeout" -le 120 ]] && echo "Warning: Your timeout is set low and may lead to premature rollbacks or skips"
pool=$(cli -c 'app kubernetes config' | grep -E "dataset\s\|" | awk -F '|' '{print $3}' | awk -F '/' '{print $1}' | tr -d " \t\n\r")

it=0
while_count=0
rm deploying 2>/dev/null
rm finished 2>/dev/null
while true
do
    if while_status=$(cli -m csv -c 'app chart_release query name,update_available,human_version,human_latest_version,status' 2>/dev/null) ; then
        ((while_count++)) 
        [[ -z $while_status ]] && continue || echo -e "$while_count\n$while_status" > all_app_status
        mapfile -t deploying_check < <(grep ",DEPLOYING," all_app_status)
        for i in "${deploying_check[@]}"
        do
            app_name=$(echo "$i" | awk -F ',' '{print $1}')
            [[ ! -e deploying ]] && touch deploying
            if ! grep -qs "$app_name,DEPLOYING" deploying; then
                echo "$app_name,DEPLOYING" >> deploying
            fi
        done
    else
        echo "Middlewared timed out. Consider setting a lower number for async applications"
        continue
    fi
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
        # loop=0
        # until [[ $loop -ge 2 || $it -ge ${#array[@]} ]];
        # do
        pre_process "${array[$it]}" &
        processes+=($!)
        ((it++))
        # ((loop++))
        # done
    elif [[ $proc_count != 0 || $(wc -l finished 2>/dev/null | awk '{ print $1 }') -lt "${#array[@]}" ]]; then # Wait for all processes to finish
        sleep 3
    else # All processes must be completed, break out of loop
        break
    fi
done
rm deploying 2>/dev/null
rm finished 2>/dev/null
echo
echo
}
export -f commander


pre_process(){
app_name=$(echo "${array[$it]}" | awk -F ',' '{print $1}') #print out first catagory, name.
printf '%s\0' "${ignore[@]}" | grep -iFxqz "${app_name}" && echo -e "\n$app_name\nIgnored, skipping" && final_check && return 0 #If application is on ignore list, skip
old_app_ver=$(echo "${array[$it]}" | awk -F ',' '{print $4}' | awk -F '_' '{print $1}' | awk -F '.' '{print $1}') #previous/current Application MAJOR Version
new_app_ver=$(echo "${array[$it]}" | awk -F ',' '{print $5}' | awk -F '_' '{print $1}' | awk -F '.' '{print $1}') #new Application MAJOR Version
old_chart_ver=$(echo "${array[$it]}" | awk -F ',' '{print $4}' | awk -F '_' '{print $2}' | awk -F '.' '{print $1}') # Old Chart MAJOR version
new_chart_ver=$(echo "${array[$it]}" | awk -F ',' '{print $5}' | awk -F '_' '{print $2}' | awk -F '.' '{print $1}') # New Chart MAJOR version
startstatus=$(echo "${array[$it]}" | awk -F ',' '{print $2}') #status of the app: STOPPED / DEPLOYING / ACTIVE
diff_app=$(diff <(echo "$old_app_ver") <(echo "$new_app_ver")) #caluclating difference in major app versions
diff_chart=$(diff <(echo "$old_chart_ver") <(echo "$new_chart_ver")) #caluclating difference in Chart versions
[[ "$diff_app" != "$diff_chart" && $update_apps == "true" ]] && echo -e "\n$app_name\nMajor Release, update manually" && final_check && return 
old_full_ver=$(echo "${array[$it]}" | awk -F ',' '{print $4}') #Upgraded From
new_full_ver=$(echo "${array[$it]}" | awk -F ',' '{print $5}') #Upraded To
rollback_version=$(echo "${array[$it]}" | awk -F ',' '{print $4}' | awk -F '_' '{print $2}')
if  grep -qs "^$app_name," failed 2>/dev/null; then
    failed_ver=$(grep "^$app_name," failed | awk -F ',' '{print $2}')
    if [[ "$failed_ver" == "$new_full_ver" ]] ; then
        echo -e "\n$app_name"
        echo -e "Skipping previously failed version:\n$new_full_ver"
        final_check
        return 0
    else 
        sed -i /"$app_name",/d failed
    fi
fi

[[ ! -e external_services ]] && touch external_services
if ! grep -qs "^$app_name," external_services ; then 
    if ! grep qs "/external-service" /mnt/"$pool"/ix-applications/releases/"$app_name"/charts/"$(find /mnt/"$pool"/ix-applications/releases/"$app_name"/charts/ -maxdepth 1 -type d -printf '%P\n' | sort -r | head -n 1)"/Chart.yaml 2>/dev/null; then
        echo "$app_name,false" >> external_services
    else
        echo "$app_name,true" >> external_services
    fi
fi

echo_array+=("\n$app_name")
if [[ $stop_before_update == "true" && "$startstatus" !=  "STOPPED" ]]; then # Check to see if user is using -S or not
    [[ "$verbose" == "true" ]] && echo_array+=("Stopping prior to update..")
    if stop_app ; then
        echo_array+=("Stopped")
    else
        echo_array+=("Error: Failed to stop $app_name")
        echo_array
        final_check
        return 1
    fi
fi
[[ "$verbose" == "true" ]] && echo_array+=("Updating..")
if update_app ;then
    echo_array+=("Updated\n$old_full_ver\n$new_full_ver")
else
    echo_array+=("Failed to update")
    echo_array
    final_check
    return
fi
if grep -qs "^$app_name,true" external_services ; then
    echo_array
    final_check
    return
else
    after_update_actions
    final_check
fi
}
export -f pre_process


update_app(){
current_loop=0
while true
do
    update_avail=$(grep "^$app_name," all_app_status | awk -F ',' '{print $3}')
    if [[ $update_avail == "true" ]]; then
        if ! cli -c 'app chart_release upgrade release_name=''"'"$app_name"'"' &> /dev/null ; then
            before_loop=$(head -n 1 all_app_status)
            current_loop=0
            until [[ "$(grep "^$app_name," all_app_status | awk -F ',' '{print $3}')" != "$update_avail" ]]   # Wait for a specific change to app status, or 3 refreshes of the file to go by.
            do
                if [[ $current_loop -gt 2 ]]; then
                    cli -c 'app chart_release upgrade release_name=''"'"$app_name"'"' &> /dev/null || return 1     # After waiting, attempt an update once more, if fails, return error code
                elif ! echo -e "$(head -n 1 all_app_status)" | grep -qs ^"$before_loop" ; then                # The file has been updated, but nothing changed specifically for the app.
                    before_loop=$(head -n 1 all_app_status)
                    ((current_loop++))
                fi
                sleep 1
            done
        fi
        break
    elif [[ $update_avail == "false" ]]; then
        break
    else 
        sleep 3
    fi
done
}
export -f update_app


stop_app(){
count=0
while [[ "$status" !=  "STOPPED" ]]
do
    status=$( grep "^$app_name," all_app_status | awk -F ',' '{print $2}')
    if [[ $count -gt 2 ]]; then # If failed to stop app 3 times, return failure to parent shell
        return 1
    elif ! cli -c 'app chart_release scale release_name='\""$app_name"\"\ 'scale_options={"replica_count": 0}' &> /dev/null ; then
        before_loop=$(head -n 1 all_app_status)
        ((count++))
        until [[ $(head -n 1 all_app_status) != "$before_loop" ]] # Upon failure, wait for status update before continuing
        do
            sleep 1
        done
    else 
        break
    fi
done
}
export -f stop_app


after_update_actions(){
SECONDS=0
count=0
if [[ $rollback == "true" || "$startstatus"  ==  "STOPPED" ]]; then
    while true
    do
        status=$(grep "^$app_name," all_app_status | awk -F ',' '{print $2}')
        if [[ $count -lt 1 && $status == "ACTIVE" && "$(grep "^$app_name," deploying 2>/dev/null | awk -F ',' '{print $2}')" != "DEPLOYING" ]]; then                # If status shows up as Active or Stopped on the first check, verify that. Otherwise it may be a false report..
            [[ "$verbose" == "true" ]] && echo_array+=("Verifying $status..")
            before_loop=$(head -n 1 all_app_status)
            current_loop=0
            until [[ "$status" != "ACTIVE" || $current_loop -gt 4 ]] # Wait for a specific change to app status, or 3 refreshes of the file to go by.
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
                [[ "$verbose" == "true" ]] && echo_array+=("Returing to STOPPED state..")
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
                    echo_array+=("Error: Run Time($SECONDS) for $app_name has exceeded Timeout($timeout)")
                    echo_array+=("If this is a slow starting application, set a higher timeout with -t")
                    echo_array+=("If this applicaion is always DEPLOYING, you can disable all probes under the Healthcheck Probes Liveness section in the edit configuration")
                    echo_array+=("Reverting update..")
                    midclt call chart.release.rollback "$app_name" "{\"item_version\": \"$rollback_version\"}" &> /dev/null || { echo_array+=("Error: Failed to rollback $app_name") ; break ; }
                    [[ "$startstatus"  ==  "STOPPED" ]] && failed="true" && after_update_actions #run back after_update_actions function if the app was stopped prior to update
                    echo "$app_name,$new_full_ver" >> failed
                    break
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
            [[ "$verbose" == "true" ]] && echo_array+=("Waiting $((timeout-SECONDS)) more seconds for $app_name to be ACTIVE")
            sleep 5
            continue
        fi
    done
fi
echo_array
}
export -f after_update_actions


echo_array(){
#Dump the echo_array, ensures all output is in a neat order. 
for i in "${echo_array[@]}"
do
    echo -e "$i"
done

}
export -f echo_array

final_check(){
    [[ ! -e finished ]] && touch finished
    echo "$app_name,finished" >> finished
}
