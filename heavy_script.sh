#!/bin/bash

#If no argument is passed, kill the script.
[[ -z "$*" ]] && echo "This script requires an arguent, use -h for help" && exit

while getopts ":hsi:mt:uUp" opt
do
    case $opt in
        h)
            echo "These arguments NEED to be ran in a specific order, you can go from TOP to BOTTOM, see example below"
            echo "-m | Initiates mounting feature, choose between unmounting and mounting PVC data"
            echo "-i | Add application to ignore list, one by one, see example below."
            echo "-t | Set a custom timeout in seconds for -u or -U: This is the ammount of time the script will wait for an application to go from DEPLOYING to ACTIVE"
            echo "-t | Set a custom timeout in seconds for -m: Amount of time script will wait for applications to stop, before timing out"
            echo "-s | sync catalog"
            echo "-U | Update all applications, ignores versions"
            echo "-u | Update all applications, does not update Major releases"
            echo "-p | Prune unused/old docker images"
            echo "EX | bash heavy_script.sh -i portainer -i arch -i sonarr -i radarr -t 600 -sUp"
            echo "EX | bash /mnt/tank/scripts/heavy_script.sh -t 8812 -m"
            exit;;
        \?)
            echo "Invalid Option -$OPTARG, type -h for help"
            exit;;
        :)
            echo "Option: -$OPTARG requires an argument" >&2
            exit;;
        i)
            ignore+="$OPTARG"
            ;;
        t)
            timeout=$OPTARG
            re='^[0-9]+$'
            ! [[ $timeout =~ $re ]] && echo -e "Error: -t needs to be assigned an interger\n$timeout is not an interger" >&2
            ;;
        m)
            echo -e "1  Mount\n2  Unmount All" && read -p "Please type a number: " selection

            if [[ $selection == "1" ]]; then
                list=$(k3s kubectl get pvc -A | sort -u | awk '{print NR-1, "\t" $1 "\t" $2 "\t" $4}' | column -t | sed "s/^0/ /")
                echo "$list" && read -p "Please type a number : " selection
                app=$(echo -e "$list" | grep ^"$selection" | awk '{print $2}' | cut -c 4-)
                pvc=$(echo -e "$list" | grep ^"$selection" || echo -e "\nInvalid selection")
                status=$(cli -m csv -c 'app chart_release query name,status' | grep -E "(,|^)$app(,|$)" | awk -F ',' '{print $2}'| tr -d " \t\n\r") && SECONDS=0
                [[ "$status" != "STOPPED" ]] && echo -e "\nScaling down $app" && midclt call chart.release.scale "$app" '{"replica_count": 0}' &> /dev/null && [[ -z $timeout ]] && echo -e "\nSetting Default Timeout to 300\nChange timeout with -t" && timeout=300 || echo -e "\nTimeout was set to $timeout"
                while [[ "$SECONDS" -le "$timeout" && "$status" != "STOPPED" ]]
                    do
                        status=$(cli -m csv -c 'app chart_release query name,status' | grep -E "(,|^)$app(,|$)" | awk -F ',' '{print $2}'| tr -d " \t\n\r")
                        echo -e "Waiting $((timeout-SECONDS)) more seconds for $app to be STOPPED" && sleep 10
                    done
                data_name=$(echo "$pvc" | awk '{print $3}')
                mount=$(echo "$pvc" | awk '{print $4}')
                path=$(find /*/*/ix-applications/releases/"$app"/volumes/ -maxdepth 0 | cut -c 6-)
                echo -e "\nMounting\n""$path""""$mount""\nTo\n/mnt/temporary/$data_name" && zfs set mountpoint=/temporary/"$data_name" "$path""$mount" && echo -e "Mounted\n\nUnmount with the following command\nzfs set mountpoint=legacy ""$path"""$mount"\nOr use the Unmount All option"
                break
            elif [[ $selection == "2" ]]; then
                mapfile -t unmount_array < <(basename -a /mnt/temporary/* | sed "s/*//")
                [[ -z $unmount_array ]] && echo "Theres nothing to unmount" && exit
                for i in "${unmount_array[@]}"
                    do
                        main=$(k3s kubectl get pvc -A | grep "$i" | awk '{print $1, $2, $4}')
                        app=$(echo "$main" | awk '{print $1}' | cut -c 4-)
                        pvc=$(echo "$main" | awk '{print $3}')
                        path=$(find /*/*/ix-applications/releases/"$app"/volumes/ -maxdepth 0 | cut -c 6-)
                        zfs set mountpoint=legacy "$path""$pvc" && echo "$i unmounted" && rmdir /mnt/temporary/"$i" || echo "failed to unmount $i"
                    done
            else
                echo "Invalid selection, type -h for help"
                break
            fi
            exit;;
        s)
            echo -e "Syncing all catalogs, please wait.." && cli -c 'app catalog sync_all' &> /dev/null && echo -e "Catalog sync complete"
            ;;
        U)
            mapfile -t array < <(cli -m csv -c 'app chart_release query name,update_available,human_version,human_latest_version,status' | grep ,true,)
            [[ -z $array ]] && echo -e "\nThere are no updates available" && continue || echo -e "\n${#array[@]} update(s) available"
            [[ -z $timeout ]] && echo -e "\nSetting Default Timeout to 300\nChange timeout with -t" && timeout=300 || echo -e "\nTimeout was set to $timeout"
            for i in "${array[@]}"
                do
                     n=$(echo "$i" | awk -F ',' '{print $1}') #print out first catagory, name.
                     ov=$(echo "$i" | awk -F ',' '{print $4}') #Old version
                     nv=$(echo "$i" | awk -F ',' '{print $5}') #New Version
                     status=$(echo "$i" | awk -F ',' '{print $2}') #status of the app: STOPPED / DEPLOYING / ACTIVE
                    if [[ "${ignore[*]}"  ==  *"${n}"* ]]; then
                            echo -e "\n$n\nIgnored, skipping"
                            continue
                    elif [[ "$status"  ==  "STOPPED" ]]; then
                            echo -e "\n$n\nUpdating" && cli -c 'app chart_release upgrade release_name=''"'"$n"'"' &> /dev/null && echo -e "Updated\n$ov\n$nv\nWas Stopped, Beginning Stop Loop" && SECONDS=0 || { echo "FAILED"; continue; }
                            while [[ "$status"  !=  "ACTIVE" ]]
                                do
                                    status=$(cli -m csv -c 'app chart_release query name,update_available,human_version,human_latest_version,status' | grep $n | awk -F ',' '{print $2}')
                                    if [[ "$status"  ==  "STOPPED" ]]; then
                                            echo -e "Stopped"
                                            break
                                    elif [[ "$SECONDS" -ge "$timeout" && "$status"  ==  "DEPLOYING" ]]; then
                                            echo -e "Error: Run Time($SECONDS) has exceeded Timeout($timeout)\nIf this is a slow starting application, set a higher time with -t\nIf this applicaion is always DEPLOYING, you can disable all probes under the Healthcheck Probes Liveness section in the edit configuration\nNot shutting down application for safety reasons, continuing to next applicaion"
                                            break
                                    elif [[ "$status"  ==  "DEPLOYING" ]]; then
                                            echo -e "Waiting $((timeout-SECONDS)) more seconds for $n to be ACTIVE" && sleep 15
                                            continue
                                    else
                                            echo -e "Returing to STOPPED state.." && midclt call chart.release.scale "$n" '{"replica_count": 0}' &> /dev/null && echo -e "Stopped"|| echo "FAILED"
                                            break
                                    fi
                                done
                    else
                            echo -e "\n$n\nUpdating" && cli -c 'app chart_release upgrade release_name=''"'"$n"'"' &> /dev/null && echo -e "Updated\n$ov\n$nv" || echo -e "FAILED"
                            continue
                    fi
                done
            ;;
        u)
            mapfile -t array < <(cli -m csv -c 'app chart_release query name,update_available,human_version,human_latest_version,status' | grep ,true,)
            [[ -z $array ]] && echo -e "\nThere are no updates available" && continue || echo -e "\n${#array[@]} update(s) available"
            [[ -z $timeout ]] && echo -e "\nSetting Default Timeout to 300\nChange timeout with -t" && timeout=300 || echo -e "\nTimeout was set to $timeout"
                for i in "${array[@]}"
                    do
                        n=$(echo "$i" | awk -F ',' '{print $1}') #print out first catagory, name.
                        ottv=$(echo "$i" | awk -F ',' '{print $4}' | awk -F '_' '{print $1}' | awk -F '.' '{print $1}') #previous Truecharts version
                        nttv=$(echo "$i" | awk -F ',' '{print $5}' | awk -F '_' '{print $1}' | awk -F '.' '{print $1}') #previous version) #New Truecharts Version
                        oav=$(echo "$i" | awk -F ',' '{print $4}' | awk -F '_' '{print $2}' | awk -F '.' '{print $1}') #previous version) #New App Version
                        nav=$(echo "$i" | awk -F ',' '{print $5}' | awk -F '_' '{print $2}' | awk -F '.' '{print $1}') #previous version) #New App Version
                        status=$(echo "$i" | awk -F ',' '{print $2}') #status of the app: STOPPED / DEPLOYING / ACTIVE
                        tt=$(diff <(echo "$ottv") <(echo "$nttv")) #caluclating difference in major Truecharts versions
                        av=$(diff <(echo "$oav") <(echo "$nav")) #caluclating difference in major app versions
                        ov=$(echo "$i" | awk -F ',' '{print $4}') #Upgraded From
                        nv=$(echo "$i" | awk -F ',' '{print $5}') #Upraded To
                        if [[ "${ignore[*]}"  ==  *"${n}"* ]]; then
                                echo -e "\n$n\nIgnored, skipping"
                                continue
                        elif [[ "$tt" == "$av" && "$status"  ==  "ACTIVE" || "$status"  ==  "DEPLOYING" ]]; then
                                echo -e "\n$n\nUpdating" && cli -c 'app chart_release upgrade release_name=''"'"$n"'"' &> /dev/null && echo -e "Updated\n$ov\n$nv" || echo "FAILED"
                                continue
                        elif [[ "$tt" == "$av" && "$status"  ==  "STOPPED" ]]; then
                            echo -e "\n$n\nUpdating" && cli -c 'app chart_release upgrade release_name=''"'$n'"' &> /dev/null && echo -e "Updated\n$ov\n$nv\nWas Stopped, Beginning Stop Loop" && SECONDS=0 || { echo "FAILED"; continue; }
                            while [[ "$status"  !=  "ACTIVE" ]]
                                do
                                    status=$(cli -m csv -c 'app chart_release query name,update_available,human_version,human_latest_version,status' | grep "$n" | awk -F ',' '{print $2}')
                                    if [[ "$status"  ==  "STOPPED" ]]; then
                                            echo -e "Stopped"
                                            break
                                    elif [[ "$SECONDS" -ge "$timeout" && "$status"  ==  "DEPLOYING" ]]; then
                                            echo -e "Error: Run Time($SECONDS) has exceeded Timeout($timeout)\nIf this is a slow starting application, set a higher time with -t\nIf this applicaion is always DEPLOYING, you can disable all probes under the Healthcheck Probes Liveness section in the edit configuration\nNot shutting down application for safety reasons, continuing to next applicaion"
                                            break
                                    elif [[ "$status"  ==  "DEPLOYING" ]]; then
                                            echo -e "Waiting $((timeout-SECONDS)) more seconds for $n to be ACTIVE" && sleep 15
                                            continue
                                    else
                                            echo "Returing to STOPPED state.." && midclt call chart.release.scale "$n" '{"replica_count": 0}' &> /dev/null && echo "Stopped"|| echo -e "FAILED"
                                            break
                                    fi
                                done
                        else
                            echo -e "\n$n\nMajor Release, update manually"
                            continue
                        fi
                    done
            ;;
        p)
            echo -e "\nPruning Docker Images" && docker image prune -af | grep Total || echo "Failed to Prune Docker Images"
    esac
done
