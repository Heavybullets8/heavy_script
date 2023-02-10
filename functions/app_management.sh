#!/bin/bash

apps=()


get_app_name() {
    local app_index="$1"
    echo "${apps[app_index-1]}" | awk -F ',' '{print $1}'
}
export -f get_app_name

prompt_app_selection() {
    echo -e "${blue}Fetching applications..${reset}"

    case "$1" in
        "ALL")
            mapfile -t apps < <(cli -m csv -c 'app chart_release query name,status' | tail -n +2 | sort | tr -d " \t\r" | awk 'NF')
            ;;
        "STOPPED")
            mapfile -t apps < <(cli -m csv -c 'app chart_release query name,status' | tail -n +2 | sort | tr -d " \t\r" | awk 'NF' | grep "STOPPED")
            ;;
        "ACTIVE")
            mapfile -t apps < <(cli -m csv -c 'app chart_release query name,status' | tail -n +2 | sort | tr -d " \t\r" | awk 'NF' | grep "ACTIVE")
            ;;
    esac

    while true; do
        echo -e "${bold}Choose an application${reset}"
        echo
        for i in "${!apps[@]}"; do
            echo "$((i+1))) ${apps[i]}" | awk -F ',' '{print $1}'
        done
        echo
        echo "0) Exit"
        read -rp "Choose an application by number: " app_index
        if [ "$app_index" -eq 0 ]; then
            exit 0
        elif [ "$app_index" -gt 0 ] && [ "$app_index" -le "${#apps[@]}" ]; then
            app_name=$(get_app_name "$app_index")
            return "$app_index"
        else
            echo -e "${red}Invalid selection. Please choose a number from the list.${reset}"
            sleep 3
        fi
    done
}
export -f prompt_app_selection


restart_app_prompt(){
    app_index=$(prompt_app_selection "ALL")
    app_name=$(get_app_name "$app_index")
    

    if ! restart_app; then
        echo -e "${red}Failed to restart ${blue}$app_name${reset}"
    else
        echo -e "${green}Restarted ${blue}$app_name${reset}"
    fi
}
export -f restart_app_prompt


delete_app_prompt(){
    app_index=$(prompt_app_selection "ALL")
    app_name=$(get_app_name "$app_index")
    
    clear -x
    title
    
    echo -e "${bold}Chosen Application: ${blue}$app_name${reset}"
    echo -e "${yellow}WARNING: This will delete the application and all associated data, including snapshots${reset}"
    echo
    while true; do
        read -rp "Continue with deletion?(y/N): " confirmation
        case "$confirmation" in
            y|Y)
                if cli -c "app chart_release delete release_name=\"$app_name\""; then
                    echo -e "${green}App $app_name deleted${reset}"
                    exit
                else
                    echo -e "${red}Failed to delete app $app_name${reset}"
                fi
                exit
                ;;
            n|N)
                echo -e "Exiting.."
                exit
                ;;
            *)
                echo -e "${red}Invalid option. Please enter 'y' or 'n'.${reset}"
                sleep 3
                ;;
        esac
    done
}


stop_app_prompt(){
    app_index=$(prompt_app_selection "ACTIVE")
    app_name=$(get_app_name "$app_index")
    
    clear -x
    title
    
    if ! cli -c 'app chart_release scale release_name='\""$app_name"\"\ 'scale_options={"replica_count": 0}' &> /dev/null; then
        echo -e "${red}Failed to stop ${blue}$app_name${reset}"
        exit 1
    else
        echo -e "${blue}$app_name ${green}Stopped${reset}"
    fi
}


start_app_prompt(){
    app_index=$(prompt_app_selection "ACTIVE")
    app_name=$(get_app_name "$app_index")
    
    clear -x
    title
    
    # Pull chart info
    initial_call=$(midclt call chart.release.get_instance "$app_name")

    # query chart name
    query_name=$(echo "$initial_call" | jq .chart_metadata.name | 
                sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//')

    # check if chart is an external service
    if [[ $query_name == "external-service" ]]; then
        echo -e "${blue}$app_name${red} is an external service.${reset}"
        echo -e "${red}These application types cannot be started.${reset}"
        exit 1
    # check if chart is an ix-chart
    elif [[ $query_name == "ix-chart" ]]; then
        echo -e "${blue}$app_name${red} is an ix-chart.${reset}"
        echo -e "${red}These application types do not have a replica assigned to them.${reset}"
        echo -e "${red}As of now these appliaction types are unsupported.${reset}"
        exit 1
    fi

    # query chosen replica count for application
    replica_count=$(echo "$initial_call" | jq .config.controller.replicas | 
                sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//')

    # Start application with chosen replica count
    if cli -c 'app chart_release scale release_name='\""$app_name"\"\ 'scale_options={"replica_count": '"$replica_count}"; then
        echo -e "${blue}$app_name ${green}Started${reset}"
        echo -e "${green}Replica count set to ${blue}$replica_count${reset}"
        exit 0
    else
        echo -e "${red}Failed to start ${blue}$app_name${reset}"
        exit 1
    fi

}
