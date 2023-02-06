#!/bin/bash

apps=()

list_applications(){

    # retrieve list of app names
    mapfile -t apps < <(cli -m csv -c 'app chart_release query name' | tail -n +2 | sort | tr -d " \t\r" | awk 'NF')

    # print out list of app names with numbered options
    for i in "${!apps[@]}"; do
        echo "$((i+1))) ${apps[i]}"
    done
}


delete_app_prompt(){
    clear -x
    title
    list_applications

    while true; do
        # prompt user to select app
        read -rp "Choose an application by number: " app_index

        # validate user selection
        if [ "$app_index" -gt 0 ] && [ "$app_index" -le "${#apps[@]}" ]; then
            # retrieve selected app name
            app_name=${apps[app_index-1]}
            # delete app
            if cli -c "app chart_release delete release_name=\"$app_name\""; then
                echo -e "${green}App $app_name deleted${reset}"
            else
                echo -e "${red}Failed to delete app $app_name${reset}"
            fi
            break
        else
            echo -e "${red}Invalid selection. Please choose a number from the list.${reset}"
        fi
    done
}


restart_app_prompt(){
    clear -x
    title
    list_applications

    while true; do
        # prompt user to select app
        read -rp "Choose an application by number: " app_index

        # validate user selection
        if [ "$app_index" -gt 0 ] && [ "$app_index" -le "${#apps[@]}" ]; then
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
        fi
    done
}
