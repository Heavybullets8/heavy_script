#!/bin/bash

backup_selection() {
    local backup_selection=""
    while true; do
        clear -x
        title
        echo -e "${bold}Backup Menu${reset}"
        echo -e "${bold}-----------${reset}"
        echo -e "1)  Create Backup"
        echo -e "2)  Delete Backup"
        echo -e "3)  Restore Backup"
        echo -e "4)  Install/Update Velero"
        echo
        echo -e "9)  Back to Main Menu"
        echo -e "0)  Exit"
        read -rt 120 -p "Please select an option by number: " backup_selection || { echo -e "${red}\nFailed to make a selection in time${reset}" ; exit; }

        case $backup_selection in
            0)
                echo -e "Exiting.."
                exit
                ;;
            1)
                read -rt 120 -p "What is the maximum number of backups you would like?: " number_of_backups || { echo -e "${red}\nFailed to make a selection in time${reset}" ; exit; }
                if ! [[ $number_of_backups =~ ^[0-9]+$  ]]; then
                    echo -e "${red}Error: The input must be an interger\n${blue}\"$number_of_backups\"${red} is not an integer${reset}" >&2 
                    exit
                fi
                if [[ "$number_of_backups" -le 0 ]]; then
                    echo -e "${red}Error: Number of backups is required to be at least 1${reset}"
                    exit
                fi
                create_backup "$number_of_backups" "direct"
                exit
                ;;
            2)
                delete_backup
                exit
                ;;
            3)
                restore_backup
                exit
                ;;
            4)
                velero_check
                exit
                ;;
            9)
                # Break the loop to go back to the main menu
                break
                ;;
            *)
                echo -e "${red}\"$backup_selection\" was not an option, please try again${reset}"
                sleep 3
                ;;
        esac
    done
}
