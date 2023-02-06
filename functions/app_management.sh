#!/bin/bash

apps=()

list_applications(){

    # retrieve list of app names
    mapfile -t apps < <(cli -q -m csv -c 'app chart_release query name' | tail -n +2 | sort)

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
            selected_app="$(echo "${apps[app_index-1]}" | tr -d ' \n\r')"
            # delete app
            if cli -c "app chart_release delete release_name=\"$selected_app\""; then
                echo -e "${green}App $selected_app deleted${reset}"
                break
            else
                echo -e "${red}Failed to delete app $selected_app${reset}"
                break
            fi
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
            selected_app="$(echo "${apps[app_index-1]}" | tr -d ' \n\r')"

            # delete app
            if cli -c "app chart_release delete release_name=\"$selected_app\""; then
                echo -e "${green}App ${blue}$selected_app${green} deleted${reset}"
                break
            else
                echo -e "${red}Failed to delete app ${blue}$selected_app${reset}"
                break
            fi
        else
            echo -e "${red}Invalid selection. Please choose a number from the list.${reset}"
        fi
    done
}
