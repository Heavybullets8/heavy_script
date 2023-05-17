#!/bin/bash


start_app_prompt(){
    while true; do
        # Prompt user to select an application if one was not passed to the function
        if [[ -z $1 ]]; then
            prompt_app_selection "STOPPED" "start"
            app_name=$(echo "${apps[app_index-1]}" | awk -F ',' '{print $1}')
            clear -x
            title
        else
            app_name="$1"
        fi

        # Query chosen replica count for the application
        replica_count=$(pull_replicas "$app_name")

        if [[ $replica_count == "0" ]]; then
            echo -e "${blue}$app_name${red} cannot be started${reset}"
            echo -e "${yellow}Replica count is 0${reset}"
            echo -e "${yellow}This could be due to:${reset}"
            echo -e "${yellow}1. The application does not accept a replica count (external services, cert-manager etc)${reset}"
            echo -e "${yellow}2. The application is set to 0 replicas in its configuration${reset}"
            echo -e "${yellow}If you beleive this to be a mistake, please submit a bug report on the github.${reset}"
            exit
        fi

        if [[ $replica_count == "null" ]]; then
            echo -e "${blue}$app_name${red} cannot be started${reset}"
            echo -e "${yellow}Replica count is null${reset}"
            echo -e "${yellow}Looks like you found an application HS cannot handle${reset}"
            echo -e "${yellow}Please submit a bug report on the github.${reset}"
            exit
        fi

        echo -e "Starting ${blue}$app_name${reset}..."


        # Check if app is a cnpg instance, or an operator instance
        output=$(check_filtered_apps "$app_name")

        if [[ $output == "${app_name},stopAll-on" ]]; then
            cli -c 'app chart_release scale release_name='\""$app_name"\"\ 'scale_options={"replica_count": '"1}" &> /dev/null
            cli -c "app chart_release update chart_release=\"$app_name\" values={\"global\": {\"stopAll\": false}}"
        elif cli -c 'app chart_release scale release_name='\""$app_name"\"\ 'scale_options={"replica_count": '"$replica_count}" &> /dev/null; then
            echo -e "${blue}$app_name ${green}Started${reset}"
            echo -e "${green}Replica count set to ${blue}$replica_count${reset}"
        else
            echo -e "${red}Failed to start ${blue}$app_name${reset}"
        fi

        if [[ -n $1 ]]; then
            break
        fi

        read -rt 120 -p "Would you like to start another application? (y/n): " choice || { echo -e "\n${red}Failed to make a selection in time${reset}" ; exit; }
        case "$(echo "$choice" | tr '[:upper:]' '[:lower:]')" in
            "yes"|"y")
                continue
                ;;
            "no"|"n"|"")
                break
                ;;
            *)
                echo "Invalid choice, please enter 'y' or 'n'"
        esac
    done
}