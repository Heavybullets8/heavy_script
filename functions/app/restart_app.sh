#!/bin/bash

# shellcheck disable=SC2120
restart_app_prompt(){
    local app_names=("$@") # Get all arguments as an array

    # If the first argument is "ALL", populate the app_names array with all apps
    if [[ ${app_names[0]} == "ALL" ]]; then
        mapfile -t app_names < <(cli -m csv -c 'app chart_release query name' | tail -n +2 | sort | tr -d " \t\r" | awk 'NF')
    fi

    # If no arguments are provided, prompt for app selection
    if [[ ${#app_names[@]} -eq 0 ]]; then
        prompt_app_selection "ALL" "restart"
        app_name=$(echo "${apps[app_index-1]}" | awk -F ',' '{print $1}')
        app_names=("$app_name")
    fi

    for app_name in "${app_names[@]}"; do
        # Only check app existence if arguments were provided and it's not "ALL"
        if [[ $1 && $1 != "ALL" && ${#app_names[@]} -gt 0 ]]; then
            if ! check_app_existence "$app_name"; then
                echo -e "${red}Error:${reset} $app_name does not exist"
                continue
            fi
        fi

        echo -e "Restarting ${blue}$app_name${reset}..."

        if ! restart_app "$app_name"; then
            echo -e "${red}Failed to restart ${blue}$app_name${reset}\n"
        else
            echo -e "${green}Restarted ${blue}$app_name${reset}\n"
        fi
    done

    # If app names were provided as arguments, we're done
    if [[ ${#app_names[@]} -gt 0 ]]; then
        return
    fi

    # If not, offer the user a chance to restart another app
    while true; do
        read -rt 120 -p "Would you like to restart another application? (y/N): " choice || { echo -e "\n${red}Failed to make a selection in time${reset}" ; exit; }
        case "$(echo "$choice" | tr '[:upper:]' '[:lower:]')" in
            "yes"|"y")
                restart_app_prompt
                break
                ;;
            "no"|"n"|"")
                break
                ;;
            *)
                echo -e "${red}Invalid choice, please enter ${blue}'y'${red} or ${blue}'n'${reset}"
        esac
    done
}
