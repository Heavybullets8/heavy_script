#!/bin/bash

mount(){
clear -x
title
echo -e "1  Mount\n2  Unmount All" && read -t 600 -p "Please type a number: " selection
[[ -z "$selection" ]] && echo "Your selection cannot be empty" && exit #Check for valid selection. If none, kill script
if [[ $selection == "1" ]]; then
    list=$(k3s kubectl get pvc -A | sort -u | awk '{print NR-1, "\t" $1 "\t" $2 "\t" $4}' | column -t | sed "s/^0/ /")
    echo "$list" && read -t 120 -p "Please type a number: " selection
    [[ -z "$selection" ]] && echo "Your selection cannot be empty" && exit #Check for valid selection. If none, kill script
    app=$(echo -e "$list" | grep ^"$selection " | awk '{print $2}' | cut -c 4- )
    [[ -z "$app" ]] && echo "Invalid Selection: $selection, was not an option" && exit #Check for valid selection. If none, kill script
    pvc=$(echo -e "$list" | grep ^"$selection ")
    status=$(cli -m csv -c 'app chart_release query name,status' | grep -E "^$app\b" | awk -F ',' '{print $2}'| tr -d " \t\n\r")
    if [[ "$status" != "STOPPED" ]]; then
        [[ -z $timeout ]] && echo -e "\nDefault Timeout: 500" && timeout=500 || echo -e "\nCustom Timeout: $timeout"
        SECONDS=0 && echo -e "\nScaling down $app" && midclt call chart.release.scale "$app" '{"replica_count": 0}' &> /dev/null
    else
        echo -e "\n$app is already stopped"
    fi
    while [[ "$SECONDS" -le "$timeout" && "$status" != "STOPPED" ]]
    do
        status=$(cli -m csv -c 'app chart_release query name,status' | grep -E "^$app\b" | awk -F ',' '{print $2}'| tr -d " \t\n\r")
        echo -e "Waiting $((timeout-SECONDS)) more seconds for $app to be STOPPED" && sleep 5
    done
    data_name=$(echo "$pvc" | awk '{print $3}')
    mount=$(echo "$pvc" | awk '{print $4}')
    volume_name=$(echo "$pvc" | awk '{print $4}')
    mapfile -t full_path < <(zfs list | grep "$volume_name" | awk '{print $1}')
    if [[  "${#full_path[@]}" -gt 1 ]]; then #if there is another app with the same name on another pool, use the current pools application, since the other instance is probably old, or unused, or a backup.
            echo "$app is a name used on more than one pool.. attempting to use your current kubernetes apps pool"
            pool=$(cli -c 'app kubernetes config' | grep -E "dataset\s\|" | awk -F '|' '{print $3}' | awk -F '/' '{print $1}' | tr -d " \t\n\r")
            full_path=$(zfs list | grep "$volume_name" | grep "$pool" | awk '{print $1}')
    fi
    echo -e "\nMounting\n$full_path\nTo\n/mnt/heavyscript/$data_name"
    zfs set mountpoint=/heavyscript/"$data_name" "$full_path" || echo "Failed to mount $app"
    echo -e "Mounted\n\nUnmount with:\nzfs set mountpoint=legacy $full_path && rmdir /mnt/heavyscript/$data_name\n\nOr use the Unmount All option\n"
    exit
elif [[ $selection == "2" ]]; then
    mapfile -t unmount_array < <(basename -a /mnt/heavyscript/* | sed "s/*//")
    [[ -z $unmount_array ]] && echo "Theres nothing to unmount" && exit
    for i in "${unmount_array[@]}"
    do
        main=$(k3s kubectl get pvc -A | grep -E "\s$i\s" | awk '{print $1, $2, $4}')
        app=$(echo "$main" | awk '{print $1}' | cut -c 4-)
        pvc=$(echo "$main" | awk '{print $3}')
        mapfile -t path < <(find /mnt/*/ix-applications/releases/"$app"/volumes/ -maxdepth 0 | cut -c 6-)
        if [[  "${#path[@]}" -gt 1 ]]; then #if there is another app with the same name on another pool, use the current pools application, since the other instance is probably old, or unused, or a backup.
            echo "$i is a name used on more than one pool.. attempting to use your current kubernetes apps pool"
            pool=$(cli -c 'app kubernetes config' | grep -E "dataset\s\|" | awk -F '|' '{print $3}' | awk -F '/' '{print $1}' | tr -d " \t\n\r")
            full_path=$(find /mnt/"$pool"/ix-applications/releases/"$app"/volumes/ -maxdepth 0 | cut -c 6-)
            zfs set mountpoint=legacy "$full_path""$pvc" && echo "$i unmounted" && rmdir /mnt/heavyscript/"$i" || echo "failed to unmount $i"
        else
            zfs set mountpoint=legacy "$path""$pvc" && echo "$i unmounted" && rmdir /mnt/heavyscript/"$i" || echo "failed to unmount $i"
        fi
    done
    rmdir /mnt/heavyscript
else
    echo "Invalid selection, \"$selection\" was not an option"
fi
}
export -f mount