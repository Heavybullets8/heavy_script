#!/bin/bash


restart_app_prompt(){
    while true; do
        prompt_app_selection "ALL"
        app_name=$(echo "${apps[app_index-1]}" | awk -F ',' '{print $1}')
        
        clear -x
        title

        echo -e "Restarting ${blue}$app_name${reset}..."

        if ! restart_app; then
            echo -e "${red}Failed to restart ${blue}$app_name${reset}"
        else
            echo -e "${green}Restarted ${blue}$app_name${reset}"
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