#!/bin/bash

application_menu(){
    while [[ $misc_selection != true ]]
    do
        clear -x
        title
        echo -e "${bold}Application Options${reset}"
        echo -e "${bold}-------------------${reset}"
        echo -e "1)  List DNS Names"
        echo -e "2)  Mount/Unmount PVC Storage"
        echo -e "3)  Open Container Shell"
        echo -e "4)  Open Container Logs"
        echo -e "5)  Start Application"
        echo -e "6)  Restart Application"
        echo -e "7)  Delete Application"
        echo -e "8)  Stop Application"
        echo
        echo -e "0)  Exit"
        read -rt 120 -p "Please select an option by number: " misc_selection || { echo -e "${red}\nFailed to make a selection in time${reset}" ; exit; }
        case $misc_selection in
            0)
                echo -e "Exiting.."
                exit
                ;;
            1)
                dns_handler
                misc_selection=true
                ;;
            2)
                mount_prompt
                misc_selection=true
                ;;
            3)
                container_shell_or_logs "shell"
                misc_selection=true
                ;;
            4)
                container_shell_or_logs "logs"
                misc_selection=true
                ;;
            5)
                start_app_prompt
                misc_selection=true
                ;;
            6)
                restart_app_prompt
                misc_selection=true
                ;;
            7)
                delete_app_prompt
                misc_selection=true
                ;;
            8)
                stop_app_prompt
                misc_selection=true
                ;;
            *)
                echo -e "${red}\"$selection\" was not an option, please try again${reset}"
                sleep 3
                continue
                ;;
        esac
    done
}