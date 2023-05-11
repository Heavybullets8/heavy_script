#!/bin/bash


sync_catalog(){
    local sync_type=$1

    if [[ $sync_type != "update" ]]; then
        echo -e "${blue}Please wait while we sync your catalog...${reset}"
    fi

    echo_sync+=("🅂 🅈 🄽 🄲") 
    cli -c 'app catalog sync_all' &> /dev/null && echo_sync+=("Catalog sync complete")

    #Dump the echo_array, ensures all output is in a neat order. 
    for i in "${echo_sync[@]}"
    do
        echo -e "$i"
    done
    echo
    echo
}