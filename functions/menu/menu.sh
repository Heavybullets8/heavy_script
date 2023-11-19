#!/bin/bash

menu_check_root() {
    if [[ $EUID -ne 0 ]]; then
        echo -e "${red}Error: That option requires root privileges."
        echo -e "Please run the script with ${blue}sudo${red} or as ${blue}root."
        echo -e "${yellow}Tip: You can re-run the last command with sudo by typing ${blue}sudo !!"
        exit 1 
    fi
}

menu() {
    while true; do
        clear -x
        title
        echo -e "${bold}Available Utilities${reset}"
        echo -e "${bold}-------------------${reset}"
        echo -e "1)  Help"
        echo -e "2)  Application Options"
        echo -e "3)  Backup Options"
        echo -e "4)  HeavyScript Options"
        echo
        echo -e "0)  Exit"
        read -rt 120 -p "Please select an option by number: " selection || { echo -e "${red}\nFailed to make a selection in time${reset}" ; exit; }

        case $selection in
            0)
                echo -e "Exiting.."
                exit
                ;;
            1)
                main_help
                exit
                ;;
            2) # Application Options
                menu_check_root
                application_menu
                ;;
            3) # Backup Options
                menu_check_root
                backup_selection
                ;;
            4) # HeavyScript Options
                heavyscript_menu
                ;;
            *)
                echo -e "${blue}\"$selection\"${red} was not an option, please try again${reset}"
                sleep 3
                ;;
        esac
    done
}
export -f menu
