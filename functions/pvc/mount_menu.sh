#!/bin/bash


mount_promt(){
    ix_apps_pool=$(cli -c 'app kubernetes config' | 
                   grep -E "pool\s\|" | 
                   awk -F '|' '{print $3}' | 
                   sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//')

    # Use mapfile command to read the output of cli command into an array
    mapfile -t pool_query < <(cli -m csv -c "storage pool query name,path" | sed -e '1d' -e '/^$/d')

    while true
    do
        clear -x
        title
        echo -e "${bold}PVC Mount Menu${reset}"
        echo -e "${bold}--------------${reset}"
        echo -e "1)  Mount"
        echo -e "2)  Unmount All"
        echo
        echo -e "0)  Exit"
        read -rt 120 -p "Please type a number: " selection || { echo -e "\n${red}Failed to make a selection in time${reset}" ; exit; }
        case $selection in
            0)
                echo -e "Exiting.."
                exit
                ;;
            1)
                mount_app_func
                exit
                ;;
            2)
                unmount_app_func
                exit
                ;;
            *)
                echo -e "${red}Invalid selection, ${blue}\"$selection\"${red} was not an option${reset}" 
                sleep 3
                continue
                ;;
        esac
    done
}