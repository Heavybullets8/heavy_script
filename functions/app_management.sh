#!/bin/bash

apps=()

list_applications(){

    # retrieve list of app names
    mapfile -t apps < <(cli -m csv -c 'app chart_release query name' | tail -n +2 | sort | tr -d " \t\r" | awk 'NF')

    # return the list of app names
    printf '%s\n' "${apps[@]}"
}


delete_app_prompt(){
    clear -x
    echo -e "${blue}Fetching applications..${reset}"
    # retrieve list of app names
    mapfile -t apps < <(list_applications)

    while true; do
        clear -x
        title
        echo -e "${bold}Choose an application to delete${reset}"
        echo
        # print out list of app names with numbered options
        for i in "${!apps[@]}"; do
            echo "$((i+1))) ${apps[i]}"
        done
        echo
        echo "0) Exit"
        # prompt user to select app
        read -rp "Choose an application by number: " app_index

        # validate user selection
        if [ "$app_index" -eq 0 ]; then
            exit 0
        elif [ "$app_index" -gt 0 ] && [ "$app_index" -le "${#apps[@]}" ]; then
            # retrieve selected app name
            app_name=${apps[app_index-1]}

            # prompt user for confirmation
            clear -x
            title
            echo -e "${bold}Chosen Application: ${blue}$app_name${reset}"
            echo -e "${yellow}WARNING: This will delete the application and all associated data, including snapshots${reset}"
            echo
            read -rp "Continue with deletion?(y/N): " confirmation
            while true; do
                case "$confirmation" in
                    y|Y)
                        # delete app
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
        else
            echo -e "${red}Invalid selection. Please choose a number from the list.${reset}"
            sleep 3
        fi
    done
}




restart_app_prompt(){
    clear -x
    echo -e "${blue}Fetching applications..${reset}"
    mapfile -t apps < <(list_applications)

    while true; do
        clear -x
        title
        echo -e "${bold}Choose an application to restart${reset}"
        echo
        # print out list of app names with numbered options
        for i in "${!apps[@]}"; do
            echo "$((i+1))) ${apps[i]}"
        done
        echo
        echo "0) Exit"
        # prompt user to select app
        read -rp "Choose an application by number: " app_index

        # validate user selection
        if [ "$app_index" -eq 0 ]; then
            exit 0
        elif [ "$app_index" -gt 0 ] && [ "$app_index" -le "${#apps[@]}" ]; then
            # retrieve selected app name
            app_name=${apps[app_index-1]}

            if ! restart_app; then
                echo -e "${red}Failed to restart ${blue}$app_name${reset}"
            else
                echo -e "${green}Restarted ${blue}$app_name${reset}"
            fi
            break
        else
            echo -e "${red}Invalid selection. Please choose a number from the list.${reset}"
            sleep 3
        fi
    done
}


stop_app_prompt(){
    clear -x
    echo -e "${blue}Fetching applications..${reset}"
    mapfile -t apps < <(list_applications)

    while true; do
        clear -x
        title
        echo -e "${bold}Choose an application to stop${reset}"
        echo
        # print out list of app names with numbered options
        for i in "${!apps[@]}"; do
            echo "$((i+1))) ${apps[i]}"
        done
        echo
        echo "0) Exit"
        # prompt user to select app
        read -rp "Choose an application by number: " app_index

        # validate user selection
        if [ "$app_index" -eq 0 ]; then
            exit 0
        elif [ "$app_index" -gt 0 ] && [ "$app_index" -le "${#apps[@]}" ]; then
            # retrieve selected app name
            app_name=${apps[app_index-1]}

            if ! cli -c 'app chart_release scale release_name='\""$app_name"\"\ 'scale_options={"replica_count": 0}' &> /dev/null; then
                echo -e "${red}Failed to stop ${blue}$app_name${reset}"
                exit 1
            else
                echo -e "${blue}$app_name${green}Stopped${reset}"
            fi
            break
        else
            echo -e "${red}Invalid selection. Please choose a number from the list.${reset}"
            sleep 3
        fi
    done



}