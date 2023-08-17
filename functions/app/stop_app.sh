#!/bin/bash


stop_app_prompt(){
    while true; do
        # Prompt user to select an application if one was not passed to the function
        if [[ -z $1 ]]; then
            prompt_app_selection "ACTIVE" "stop"
            app_name=$(echo "${apps[app_index-1]}" | awk -F ',' '{print $1}')
            clear -x
            title
        else 
            app_name="$1"
        fi
        
        echo -e "Stopping ${blue}$app_name${reset}..."

        stop_app "normal" "$app_name" "${timeout:-50}"
        result=$(handle_stop_code "$?")
        if [[ $? -eq 1 ]]; then
            echo -e "${red}${result}${reset}"
            exit 1
        else
            echo -e "${green}${result}${reset}"
        fi

        if [[ -n $1 ]]; then
            break
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