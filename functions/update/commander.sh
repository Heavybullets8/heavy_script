#!/bin/bash


get_app_info() {
    cli -m csv -c 'app chart_release query name,update_available,human_version,human_latest_version,container_images_update_available,status' |
        tr -d " \t\r" |
        grep -E ",true($|,)" |
        sort
}

echo_updates_header() {
    echo -e "🅄 🄿 🄳 🄰 🅃 🄴 🅂"
}

display_update_status() {
    if [[ -z ${array[*]} ]]; then
        echo "There are no updates available"
        echo -e "\n"
        return 0
    else
        echo "Update(s) Available: ${#array[@]}"
    fi

    echo "Asynchronous Updates: $concurrent"

    if [[ -z $timeout ]]; then
        echo "Default Timeout: 500" && timeout=500
    else
        echo "Custom Timeout: $timeout"
    fi

    if [[ "$timeout" -le 120 ]]; then
        echo "Warning: Your timeout is set low and may lead to premature rollbacks or skips"
    fi

    if [[ $ignore_image_update == true ]]; then
        echo "Image Updates: Disabled"
    else
        echo "Image Updates: Enabled"
    fi
}

# Skip if the app is in the ignore list
skip_app_on_ignore_list() {
    if printf '%s\0' "${ignore[@]}" | grep -iFxqz "${app_name}"; then
        echo -e "\n$app_name\nIgnored, skipping"
        return 0
    fi
    return 1
}

# Skip if there's a major release
skip_major_release() {
    if [[ "$old_app_ver" != "$new_app_ver" ]] && [[ "$old_chart_ver" != "$new_chart_ver" ]]; then
        echo -e "\n$app_name\nSkipping major app and chart release\n$old_full_ver\n$new_full_ver"
        return 0
    elif [[ "$old_app_ver" != "$new_app_ver" ]]; then
        echo -e "\n$app_name\nSkipping major app release\n$old_full_ver\n$new_full_ver"
        return 0
    elif [[ "$old_chart_ver" != "$new_chart_ver" ]]; then
        echo -e "\n$app_name\nSkipping major chart release\n$old_full_ver\n$new_full_ver"
        return 0
    fi
    return 1
}

# Skip if the app version has previously failed
skip_previously_failed_version() {
    if grep -qs "^$app_name," failed 2>/dev/null; then
        failed_ver=$(grep "^$app_name," failed | awk -F ',' '{print $2}')
        if [[ "$failed_ver" == "$new_full_ver" ]]; then
            echo -e "\n$app_name\nSkipping previously failed version\n$new_full_ver"
            return 0
        else
            sed -i /"$app_name",/d failed
        fi
    fi
    return 1
}

get_apps_with_status() {
    local app_name status

    # Call the existing function and process its output
    while IFS=, read -r app_name status; do
        # If the status is "stopAll-on" or "operator", append the app_name and status to the apps_with_status array
        if [[ "$status" == "stopAll-on" ]] || [[ "$status" == "operator" ]]; then
            apps_with_status+=("$app_name,$status")
        fi
    done < <(check_filtered_apps "${array[@]/,*}")
}

# Skip if the image update should be ignored
skip_image_update() {
    if [[ $old_full_ver == "$new_full_ver" && $ignore_image_update == true ]]; then
        echo -e "\n$app_name\nImage update, skipping.."
        return 0
    fi
    return 1
}

process_apps() {
    local filtered_apps=()

    for app in "${array[@]}"; do
        # process each app and potentially remove it from the array
        app_name=$(echo "$app" | awk -F ',' '{print $1}')
        old_full_ver=$(echo "$app" | awk -F ',' '{print $4}')
        new_full_ver=$(echo "$app" | awk -F ',' '{print $5}')
        old_app_ver=$(echo "$old_full_ver" | awk -F '_' '{print $1}' | awk -F '.' '{print $1}')
        new_app_ver=$(echo "$new_full_ver" | awk -F '_' '{print $1}' | awk -F '.' '{print $1}')
        old_chart_ver=$(echo "$old_full_ver" | awk -F '_' '{print $2}' | awk -F '.' '{print $1}')
        new_chart_ver=$(echo "$new_full_ver" | awk -F '_' '{print $2}' | awk -F '.' '{print $1}')

        if skip_app_on_ignore_list; then
            continue
        fi

        if [[ $update_all_apps != true ]]; then
            if skip_major_release; then
                continue
            fi
        fi

        if skip_previously_failed_version; then
            continue
        fi

        if skip_image_update; then
            continue
        fi

        # Add the app to the filtered_apps array if it passes all the conditions
        filtered_apps+=("$app")
    done
    array=("${filtered_apps[@]}")
}


handle_concurrency() {
    local index=0
    local iteration_count=0
    rm deploying finished 2>/dev/null

    # Loop until all processes are finished or the total number of finished processes equals the length of the array
    while [[ ${#processes[@]} != 0 || $(wc -l finished 2>/dev/null | awk '{ print $1 }') -lt "${#array[@]}" ]]; do
        if while_status=$(cli -m csv -c 'app chart_release query name,update_available,human_version,human_latest_version,container_images_update_available,status' 2>/dev/null) ; then
            ((iteration_count++))
            if [[ -n $while_status ]]; then
                echo -e "$iteration_count\n$while_status" > all_app_status
            fi

            # Check for applications with a "DEPLOYING" status and add them to the 'deploying' file
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

        # Check if background jobs are still running; if not, remove them from the 'processes' array
        for i in "${!processes[@]}"; do
            kill -0 "${processes[i]}" &> /dev/null || unset "processes[$i]"
        done
        processes=("${processes[@]}")

        # Start new background jobs if the number of concurrent jobs is less than the allowed number ($concurrent)
        if [[ $index -lt ${#array[@]} && "${#processes[@]}" -lt "$concurrent" ]]; then
            pre_process "${array[$index]}" &
            processes+=($!)
            ((index++))
        else 
            sleep 3
        fi
    done

    # Clean up temporary files
    rm deploying finished 2>/dev/null
    echo
    echo
}


commander() {
    apps_with_status=()
    mapfile -t array < <(get_app_info)
    echo_updates_header
    
    display_update_status
    process_apps

    if [[ ${#array[@]} == 0 ]]; then
        echo
        echo
        return
    fi

    if [[ $rollback == true ]]; then 
        get_apps_with_status
    fi

    handle_concurrency
}
