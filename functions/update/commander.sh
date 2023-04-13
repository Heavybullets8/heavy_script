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

    echo "Asynchronous Updates: $concurrent"
    
    
    if [[ -z $timeout ]]; then
        echo "Default Timeout: 500" && timeout=500
    else
        echo "Custom Timeout: $timeout"
    fi

    if [[ "$timeout" -le 120 ]];then 
        echo "Warning: Your timeout is set low and may lead to premature rollbacks or skips"
    fi

    if [[ $ignore_image_update == true ]]; then
        echo "Image Updates: Disabled"
    else
        echo "Image Updates: Enabled"
    fi

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
        elif [[ "$diff_app" != "$diff_chart" && $update_all_apps != true ]] ; then
            echo -e "\n$app_name\nSkipping Major Release"
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
        elif [[ $old_full_ver == "$new_full_ver" && $ignore_image_update == true ]]; then
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
        if [[ $index -lt ${#array[@]} && "${#processes[@]}" -lt "$concurrent" ]]; then
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