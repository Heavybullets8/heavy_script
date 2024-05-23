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
        echo -e "3)  Restore All Backups"
        echo -e "4)  Restore Single Backup"
        echo -e "5)  List Backups"
        echo -e "6)  Import Backup"
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
                    echo -e "${red}Error: The input must be an integer\n${blue}\"$number_of_backups\"${red} is not an integer${reset}" >&2 
                    exit
                fi
                if [[ "$number_of_backups" -le 0 ]]; then
                    echo -e "${red}Error: Number of backups is required to be at least 1${reset}"
                    exit
                fi
                backup_handler --create "$number_of_backups"
                exit
                ;;
            2)
                backup_handler --delete
                exit
                ;;
            3)
                read -rt 120 -p "Enter the backup name to restore (leave empty to select interactively): " backup_name || { echo -e "${red}\nFailed to make a selection in time${reset}" ; exit; }
                if [[ -z "$backup_name" ]]; then
                    backup_handler --restore-all
                else
                    backup_handler --restore-all "$backup_name"
                fi
                exit
                ;;
            4)
                read -rt 120 -p "Enter the backup name to restore (leave empty to select interactively): " backup_name || { echo -e "${red}\nFailed to make a selection in time${reset}" ; exit; }
                if [[ -z "$backup_name" ]]; then
                    backup_handler --restore-single
                else
                    backup_handler --restore-single "$backup_name"
                fi
                exit
                ;;
            5)
                backup_handler --list
                exit
                ;;
            6)
                read -rt 120 -p "Enter the backup name to import: " backup_name || { echo -e "${red}\nFailed to make a selection in time${reset}" ; exit; }
                read -rt 120 -p "Enter the app name to import: " app_name || { echo -e "${red}\nFailed to make a selection in time${reset}" ; exit; }
                if [[ -z "$backup_name" ]] || [[ -z "$app_name" ]]; then
                    echo -e "${red}Error: Both backup name and app name are required${reset}"
                    exit
                fi
                backup_handler --import "$backup_name" "$app_name"
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
