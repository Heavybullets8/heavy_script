#!/bin/bash


restart_app(){
    dep_name=$(k3s kubectl -n ix-"$app_name" get deploy | sed -e '1d' -e 's/ .*//')
    if k3s kubectl -n ix-"$app_name" rollout restart deploy "$dep_name" &>/dev/null; then
        return 0
    else
        return 1
    fi
}


rollback_app() {
    app_update_avail=$(grep "^$app_name," all_app_status | awk -F ',' '{print $3}')

    # Continuously try to rollback the app until it is successful or the maximum number of tries is reached
    for (( count=0; count<3; count++ )); do
        if [[ "$app_update_avail" == "true" ]]; then
            return 0
        elif timeout 150s cli -c "app chart_release rollback release_name=\"$app_name\" rollback_options={\"item_version\": \"$rollback_version\"}" &> /dev/null; then
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
                if timeout 250s cli -c 'app chart_release upgrade release_name=''"'"$app_name"'"' &> /dev/null; then
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