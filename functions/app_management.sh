#!/bin/bash

apps=()


prompt_app_selection() {
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
            mapfile -t apps < <(cli -m csv -c 'app chart_release query name,status' | tail -n +2 | sort | tr -d " \t\r" | awk 'NF' | grep "ACTIVE")
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
        echo -e "${bold}Choose an application${reset}"
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



delete_app_prompt(){
    while true; do
        prompt_app_selection "ALL"
        app_name=$(echo "${apps[app_index-1]}" | awk -F ',' '{print $1}')
        
        clear -x
        title

        echo -e "Stopping ${blue}$app_name${reset}..."

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


stop_app_prompt(){
    while true; do
        prompt_app_selection "ACTIVE"
        app_name=$(echo "${apps[app_index-1]}" | awk -F ',' '{print $1}')
        
        clear -x
        title
        
        echo -e "Stopping ${blue}$app_name${reset}..."

        if ! stop_app "normal" "$app_name" "${timeout:-100}"; then
            echo -e "${red}Failed to stop ${blue}$app_name${reset}"
        else
            echo -e "${blue}$app_name ${green}Stopped${reset}"
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



start_app_prompt(){
    while true; do
        prompt_app_selection "STOPPED"
        app_name=$(echo "${apps[app_index-1]}" | awk -F ',' '{print $1}')
        
        clear -x
        title

        # Query chosen replica count for the application
        replica_count=$(replica_count "$app_name")

        if [[ $replica_count == "0" ]]; then
            echo -e "${blue}$app_name${red} cannot be started${reset}"
            echo -e "${yellow}Replica count is 0${reset}"
            echo -e "${yellow}This could be due to:${reset}"
            echo -e "${yellow}1. The application does not accept a replica count (external services, cert-manager etc)${reset}"
            echo -e "${yellow}2. The application is set to 0 replicas in its configuration${reset}"
            echo -e "${yellow}If you beleive this to be a mistake, please submit a bug report on the github.${reset}"
            break
        fi

        echo -e "Starting ${blue}$app_name${reset}..."


        # Check for cnpg pods and scale the application
        cnpg=$(k3s kubectl get pods -n ix-"$app_name" -o=name | grep -q -- '-cnpg-' && echo "true" || echo "false")

        if [[ $cnpg == "true" ]]; then
            k3s kubectl get deployments,statefulsets -n ix-"$app_name" | grep -vE -- "(NAME|^$|-cnpg-)" | awk '{print $1}' | sort -r | xargs -I{} k3s kubectl scale --replicas="$replica_count" -n ix-"$app_name" {} &>/dev/null
            #TODO: Add a check to ensure the pods are running
            echo -e "${yellow}Sent the command to start all pods in: $app_name${reset}"
            echo -e "${yellow}However, HeavyScript cannot monitor the new applications${reset}"
            echo -e "${yellow}with the new postgres backend to ensure it worked..${reset}"
        elif cli -c 'app chart_release scale release_name='\""$app_name"\"\ 'scale_options={"replica_count": '"$replica_count}" &> /dev/null; then
            echo -e "${blue}$app_name ${green}Started${reset}"
            echo -e "${green}Replica count set to ${blue}$replica_count${reset}"
        else
            echo -e "${red}Failed to start ${blue}$app_name${reset}"
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

