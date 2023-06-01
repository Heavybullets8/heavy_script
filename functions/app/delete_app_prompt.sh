#!/bin/bash


delete_app_prompt(){
    while true; do
        # Prompt user to select an application if one was not passed to the function
        if [[ -z $1 ]]; then
            prompt_app_selection "ALL" "delete"
            app_name=$(echo "${apps[app_index-1]}" | awk -F ',' '{print $1}')
            clear -x
            title
        else
            app_name="$1"
        fi

        clear -x
        title

        echo -e "${bold}Chosen Application: ${blue}$app_name${reset}"
        echo -e "${yellow}WARNING: This will delete the application and all associated data, including snapshots${reset}"
        echo
        while true; do
            read -rt 120 -p "Continue with deletion?(y/n): " confirmation || { echo -e "\n${red}Failed to make a selection in time${reset}" ; exit; }
            case "$(echo "$confirmation" | tr '[:upper:]' '[:lower:]')" in
                "yes"|"y")
                    if cli -c "app chart_release delete release_name=\"$app_name\""; then
                        echo -e "${green}App $app_name deleted${reset}"
                    else
                        echo -e "${red}Failed to delete app $app_name${reset}"
                    fi
                    break
                    ;;
                "no"|"n"|"")
                    echo -e "Exiting.."
                    break
                    ;;
                *)
                    echo -e "${red}Invalid option. Please enter 'y' or 'n'.${reset}"
                    sleep 3
                    ;;
            esac
        done

        if [[ -n $1 ]]; then
            break
        fi

        read -rt 120 -p "Would you like to delete another application? (y/n): " choice || { echo -e "\n${red}Failed to make a selection in time${reset}" ; exit; }
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