#!/bin/bash


mount(){
    pool=$(cli -c 'app kubernetes config' | grep -E "pool\s\|" | awk -F '|' '{print $3}' | tr -d " \t\n\r")
    while true
    do
        clear -x
        title
        echo "PVC Mount Menu"
        echo "--------------"
        echo "1)  Mount"
        echo "2)  Unmount All"
        echo
        echo "0)  Exit"
        read -rt 120 -p "Please type a number: " selection || { echo -e "\nFailed to make a selection in time" ; exit; }
        case $selection in
            0)
                echo "Exiting.."
                exit
                ;;
            1)
                call=$(k3s kubectl get pvc -A | sort -u | awk '{print $1 "\t" $2 "\t" $4}' | sed "s/^0/ /")
                mount_list=$(echo "$call" | sed 1d | nl -s ") ")
                mount_title=$(echo "$call" | head -n 1)
                list=$(echo -e "# $mount_title\n$mount_list" | column -t)
                while true
                do
                    clear -x
                    title
                    echo "$list" 
                    echo 
                    echo "0)  Exit"
                    read -rt 120 -p "Please type a number: " selection || { echo -e "\nFailed to make a selection in time" ; exit; }
                    
                    #Check for valid selection. If no issues, continue
                    [[ $selection == 0 ]] && echo "Exiting.." && exit
                    app=$(echo -e "$list" | grep ^"$selection)" | awk '{print $2}' | cut -c 4- )
                    [[ -z "$app" ]] && echo "Invalid Selection: $selection, was not an option" && sleep 3 && continue 
                    pvc=$(echo -e "$list" | grep ^"$selection)")

                    #Stop applicaiton if not stopped
                    status=$(cli -m csv -c 'app chart_release query name,status' | grep "^$app," | awk -F ',' '{print $2}'| tr -d " \t\n\r")
                    if [[ "$status" != "STOPPED" ]]; then
                        echo -e "\nStopping $app prior to mount"
                        if ! cli -c 'app chart_release scale release_name='\""$app"\"\ 'scale_options={"replica_count": 0}' &> /dev/null; then
                            echo "Failed to stop $app"
                            exit 1
                        else
                            echo "Stopped"
                        fi
                    else
                        echo -e "\n$app is already stopped"
                    fi

                    #Grab data then output and mount
                    data_name=$(echo "$pvc" | awk '{print $3}')
                    volume_name=$(echo "$pvc" | awk '{print $4}')
                    full_path=$(zfs list -t filesystem -r "$pool"/ix-applications/releases/"$app"/volumes -o name -H | grep "$volume_name")
                    if ! zfs set mountpoint=/heavyscript/"$data_name" "$full_path" ; then
                        echo "Error: Failed to mount $app"
                        exit 1
                    else
                        echo -e "\nMounted\n$data_name"
                    fi
                    echo -e "\nUnmount with:\nzfs set mountpoint=legacy $full_path && rmdir /mnt/heavyscript/$data_name\n\nOr use the Unmount All option\n"
                    
                    #Ask if user would like to mount something else
                    while true
                    do
                        echo
                        read -rt 120 -p "Would you like to mount anything else? (y/N): " yesno || { echo -e "\nFailed to make a selection in time" ; exit; }
                        case $yesno in
                        [Yy] | [Yy][Ee][Ss])
                            clear -x
                            title
                            break
                            ;;
                        [Nn] | [Nn][Oo])
                            exit
                            ;;
                        *)
                            echo "Invalid selection \"$yesno\" was not an option" 
                            sleep 3
                            continue
                            ;;
                        esac
                    done
                done
                ;;
            2)
                # Unmount all pvcs in the heavyscript directory
                mapfile -t unmount_array < <(basename -a /mnt/heavyscript/* | sed "s/*//")
                if [[ -z ${unmount_array[*]} ]]; then
                    echo "There are no PVCS to unmount."
                    sleep 3
                else
                    for pvc_name in "${unmount_array[@]}"; do
                        # Get the PVC details
                        main=$(k3s kubectl get pvc -A | grep -E "\s$pvc_name\s" | awk '{print $1, $2, $4}')
                        app=$(echo "$main" | awk '{print $1}' | cut -c 4-)
                        pvc=$(echo "$main" | awk '{print $3}')
                        full_path=$(find /mnt/"$pool"/ix-applications/releases/"$app"/volumes/ -maxdepth 0 | cut -c 6-)

                        # Set the mountpoint to "legacy" and unmount
                        if zfs set mountpoint=legacy "$full_path""$pvc"; then
                            echo "$pvc_name unmounted successfully."
                            rmdir /mnt/heavyscript/"$pvc_name"
                        else
                            echo "Failed to unmount $pvc_name."
                        fi
                    done
                    rmdir /mnt/heavyscript
                    sleep 3
                fi
                ;;
            *)
                echo "Invalid selection, \"$selection\" was not an option"
                sleep 3
                continue
                ;;
        esac
    done
}
export -f mount