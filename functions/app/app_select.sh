#!/bin/bash


apps=()


prompt_app_selection() {
    local action="$2"
    
    clear -x
    echo -e "${blue}Fetching applications..${reset}"

    case "$1" in
        "ALL")
            mapfile -t apps < <(cli -m csv -c 'app chart_release query name,status' | tail -n +2 | sort | tr -d " \t\r" | awk 'NF')
            search_type="Any"
            ;;
        "STOPPED")
            mapfile -t apps < <(cli -m csv -c 'app chart_release query name,status' | tail -n +2 | sort | tr -d " \t\r" | awk 'NF' | grep "STOPPED")
            search_type="STOPPED"
            ;;
        "ACTIVE")
            mapfile -t apps < <(cli -m csv -c 'app chart_release query name,status' | tail -n +2 | sort | tr -d " \t\r" | awk 'NF' | grep -E "ACTIVE|DEPLOYING")
            search_type="ACTIVE"
            ;;
    esac

    if [ "${#apps[@]}" -eq 0 ]; then
        echo -e "${yellow}Application type: ${blue}$search_type${reset}"
        echo -e "${yellow}Not found..${reset}"
        exit 1
    fi

    clear -x
    title

    while true; do
        echo -e "${bold}Choose an application to: $action${reset}"
        echo
        for i in "${!apps[@]}"; do
            echo "$((i+1))) ${apps[i]}" | awk -F ',' '{print $1}'
        done
        echo
        echo "0) Exit"
        read -rt 120 -p "Choose an application by number: " app_index || { echo -e "\n${red}Failed to make a selection in time${reset}" ; exit; }
        if [ "$app_index" -eq 0 ]; then
            exit 0
        elif [ "$app_index" -gt 0 ] && [ "$app_index" -le "${#apps[@]}" ]; then
            app_name=$(echo "${apps[app_index-1]}" | awk -F ',' '{print $1}')
            return "$app_index"
        else
            echo -e "${red}Invalid selection. Please choose a number from the list.${reset}"
            sleep 3
        fi
    done
}

