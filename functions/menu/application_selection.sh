#!/bin/bash

application_menu() {
    local misc_selection=""
    while true; do
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
        echo -e "9)  Back to Main Menu"
        echo -e "0)  Exit"
        read -rt 120 -p "Please select an option by number: " misc_selection || { echo -e "${red}\nFailed to make a selection in time${reset}" ; exit; }

        case $misc_selection in
            0)
                echo -e "Exiting.."
                exit
                ;;
            1)
                dns_handler
                exit
                ;;
            2)
                mount_prompt
                exit
                ;;
            3)
                container_shell_or_logs "shell"
                exit
                ;;
            4)
                container_shell_or_logs "logs"
                exit
                ;;
            5)
                start_app_prompt
                exit
                ;;
            6)
                restart_app_prompt
                exit
                ;;
            7)
                delete_app_prompt
                exit
                ;;
            8)
                stop_app_prompt
                exit
                ;;
            9)
                # Break the loop to go back to the main menu
                break
                ;;
            *)
                echo -e "${red}\"$misc_selection\" was not an option, please try again${reset}"
                sleep 3
                ;;
        esac
    done
}
