#!/bin/bash


restart_app_prompt(){
    while true; do
        # Prompt user to select an application if one was not passed to the function
        if [[ -z $1 ]]; then
            prompt_app_selection "ALL" "restart"
            app_name=$(echo "${apps[app_index-1]}" | awk -F ',' '{print $1}')
        else
            app_name="$1"
        fi

        
        clear -x
        title

        echo -e "Restarting ${blue}$app_name${reset}..."

        if ! restart_app; then
            echo -e "${red}Failed to restart ${blue}$app_name${reset}"
        else
            echo -e "${green}Restarted ${blue}$app_name${reset}"
        fi

        if [[ -z $1 ]]; then
            break
        fi

        read -rt 120 -p "Would you like to restart another application? (y/N): " choice || { echo -e "\n${red}Failed to make a selection in time${reset}" ; exit; }
        case "$(echo "$choice" | tr '[:upper:]' '[:lower:]')" in
            "yes"|"y")
                continue
                ;;
            "no"|"n"|"")
                break
                ;;
            *)
                echo -e "${red}Invalid choice, please enter ${blue}'y'${red} or ${blue}'n'${reset}"
        esac
    done
}