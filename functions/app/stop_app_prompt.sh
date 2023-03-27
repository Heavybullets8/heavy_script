#!/bin/bash


stop_app_prompt(){
    while true; do
        prompt_app_selection "ACTIVE"
        app_name=$(echo "${apps[app_index-1]}" | awk -F ',' '{print $1}')
        
        clear -x
        title
        
        echo -e "Stopping ${blue}$app_name${reset}..."

        stop_app "normal" "$app_name" "${timeout:-50}"
        result=$(handle_stop_code "$?")
        if [[ $? -eq 1 ]]; then
            echo -e "${red}${result}${reset}"
            exit 1
        else
            echo -e "${green}${result}${reset}"
        fi

        read -rt 120 -p "Would you like to stop another application? (y/n): " choice || { echo -e "\n${red}Failed to make a selection in time${reset}" ; exit; }
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