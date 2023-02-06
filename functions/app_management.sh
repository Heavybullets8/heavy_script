#!/bin/bash

apps=()

list_applications(){

    # retrieve list of app names
    mapfile -t apps < <(cli -m csv -c 'app chart_release query name' | tail -n +2 | sort | tr -d " \t\r" | awk 'NF')

    # return the list of app names
    printf '%s\n' "${apps[@]}"
}


delete_app_prompt(){
    # retrieve list of app names
    mapfile -t apps < <(list_applications)

    while true; do
        clear -x
        title
        # print out list of app names with numbered options
        for i in "${!apps[@]}"; do
            echo "$((i+1))) ${apps[i]}"
        done

        # prompt user to select app
        read -rp "Choose an application by number: " app_index

        # validate user selection
        if [ "$app_index" -gt 0 ] && [ "$app_index" -le "${#apps[@]}" ]; then
            # retrieve selected app name
            app_name=${apps[app_index-1]}

            # prompt user for confirmation
            clear -x
            title
            echo -e "${bold}Chosen Application: ${blue}$app_name${reset}"
            echo -e "${yellow}WARNING: This will delete the application and all associated data, including snapshots${reset}"
            echo
            read -rp "Are you sure you want to delete this application?(y/N): " confirmation
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
    mapfile -t list_apps < <(list_applications)

    while true; do
        clear -x
        title
        # print out list of app names with numbered options
        for i in "${!apps[@]}"; do
            echo "$((i+1))) ${apps[i]}"
        done
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
            sleep 3
        fi
    done
}
