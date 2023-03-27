#!/bin/bash


menu(){
    clear -x
    title
    echo -e "${bold}Available Utilities${reset}"
    echo -e "${bold}-------------------${reset}"
    echo -e "1)  Help"
    echo -e "2)  Application Options"
    echo -e "3)  Backup Options"
    echo -e "4)  HeavyScript Options"
    echo -e "5)  Patches"
    echo
    echo -e "0)  Exit"
    read -rt 120 -p "Please select an option by number: " selection || { echo -e "${red}\nFailed to make a selection in time${reset}" ; exit; }


    case $selection in
        0)
            echo -e "Exiting.."
            exit
            ;;
        1)
            help
            ;;
        
        # Applicaiton Options
        2)
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
                        dns
                        misc_selection=true
                        ;;
                    2)
                        mount
                        misc_selection=true
                        ;;
                    3)
                        container_shell_or_logs
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
            ;;
        # Backup Options
        3)
            while [[ $backup_selection != true ]]
            do
                clear -x
                title
                echo -e "${bold}Backup Menu${reset}"
                echo -e "${bold}-----------${reset}"
                echo -e "1)  Create Backup"
                echo -e "2)  Delete Backup"
                echo -e "3)  Restore Backup"
                echo
                echo -e "0)  Exit"
                read -rt 120 -p "Please select an option by number: " backup_selection || { echo -e "${red}\nFailed to make a selection in time${reset}" ; exit; }
                case $backup_selection in
                    0)
                        echo -e "Exiting.."
                        exit
                        ;;
                    1)
                        read -rt 120 -p "What is the maximun number of backups you would like?: " number_of_backups || { echo -e "${red}\nFailed to make a selection in time${reset}" ; exit; }
                        if ! [[ $number_of_backups =~ ^[0-9]+$  ]]; then
                            echo -e "${red}Error: The input must be an interger\n${blue}\"""$number_of_backups""\"${red} is not an interger${reset}" >&2 
                            exit
                        fi
                        if [[ "$number_of_backups" -le 0 ]]; then
                            echo -e "${red}Error: Number of backups is required to be at least 1${reset}"
                            exit
                        fi
                        backup_selection=true
                        ;;
                    2)
                        backup_selection=true
                        deleteBackup
                        ;;
                    3)
                        backup_selection=true
                        restore
                        ;;
                    *)
                        echo -e "${red}\"$selection\" was not an option, please try again${reset}"
                        sleep 3
                        continue
                        ;;
                esac
            done
            ;;
            
        # HeavyScript Options
        4)
            while [[ $misc_selection != true ]]
            do
                clear -x
                title
                echo -e "${bold}HeavyScript Options Menu${reset}"
                echo -e "${bold}------------------------${reset}"
                echo -e "1)  Self Update"
                echo -e "2)  Choose Branch"
                echo -e "3)  Add Script to Global Path"
                echo -e "${gray}This will download the one liner, and add it to your global path, you only need to do this once.${reset} "
                echo
                echo -e "0)  Exit"
                read -rt 120 -p "Please select an option by number: " misc_selection || { echo -e "${red}\nFailed to make a selection in time${reset}" ; exit; }
                case $misc_selection in
                    0)
                        echo -e "Exiting.."
                        exit
                        ;;
                    1)
                        misc_selection=true
                        self_update
                        ;;
                    2)
                        misc_selection=true
                        choose_branch
                        ;;
                    3)
                        misc_selection=true
                        add_script_to_global_path
                        ;;
                    *)
                        echo -e "${blue}\"$selection\"${red} was not an option, please try again${reset}"
                        sleep 3
                        continue
                        ;;
                esac
            done
            ;;
        # Patches
        5) 
            # Give users the option to run patch_2212_backups or choose_branch
            while [[ $misc_selection != true ]]
            do
                clear -x
                title
                echo -e "${bold}Patch Menu${reset}"
                echo -e "${bold}----------${reset}"
                echo -e "1)  Patch 22.12.0 Restore"
                echo -e "${gray}- - Fixes issue on 22.12.0 where restore points were being saved with empty PVC data${reset}"
                echo
                echo -e "2)  Patch 22.12.0 Backups"
                echo -e "${gray}- - Fixes issue on 22.12.0 where backups would fail on certain applications${reset}"
                echo
                echo -e "0)  Exit"
                read -rt 120 -p "Please select an option by number: " misc_selection || { echo -e "${red}\nFailed to make a selection in time${reset}" ; exit; }
                case $misc_selection in
                    0)
                        echo -e "Exiting.."
                        exit
                        ;;
                    1)
                        misc_selection=true
                        patch_2212_backups
                        ;;
                    2)
                        misc_selection=true
                        patch_2212_backups2
                        ;;
                    *)
                        echo -e "${blue}\"$selection\"${red} was not an option, please try again${reset}"
                        sleep 3
                        continue
                        ;;
                esac
            done
            ;;
        *)
            echo -e "${blue}\"$selection\"${red} was not an option, please try again${reset}"
            sleep 3
            menu
            ;;
    esac
    echo
}
export -f menu
