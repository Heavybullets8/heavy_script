#!/bin/bash


prune(){
    echo -e "🄿 🅁 🅄 🄽 🄴"  
    version="$(cli -c 'system version' | 
               awk -F '-' '{print $3}' | 
               awk -F '.' '{print $1 $2}' |  
               tr -d " \t\r\.")"
    if (( "$version" >= 2310 )); then
        if ! cli -c 'app container config prune prune_options={"remove_unused_images": true}' &>/dev/null ; then
            echo -e "Failed to Prune Images"
        else
            echo -e "Pruned Images"
        fi
    elif (( "$version" >= 2212 )); then
        if ! cli -c 'app container config prune prune_options={"remove_unused_images": true, "remove_stopped_containers": true}' | head -n -4; then
            echo -e "Failed to Prune Docker Images"
        fi
    else
        if ! docker image prune -af | grep "^Total"; then
            echo -e "Failed to Prune Docker Images"
        fi
    fi
}
export -f prune