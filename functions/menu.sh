#!/bin/bash


menu(){
    clear -x
    title
    echo -e "${bold}Available Utilities${reset}"
    echo -e "${bold}-------------------${reset}"
    echo "1)  Help"
    echo "2)  List DNS Names"
    echo "3)  Mount and Unmount PVC storage"
    echo "4)  Backup Options"
    echo "5)  HeavyScript Options"
    echo "6)  Update Applications"
    echo "7)  Command to Container / Container Logs"
    echo "8)  Patches"
    echo
    echo "0)  Exit"
    read -rt 120 -p "Please select an option by number: " selection || { echo -e "${red}\nFailed to make a selection in time${reset}" ; exit; }


    case $selection in
        0)
            echo "Exiting.."
            exit
            ;;
        1)
            help
            ;;
        
        # List DNS Names
        2)
            dns 
            ;;
        
        # Mount and Unmount PVC storage
        3)
            mount
            ;;
        
        # Backup Options
        4)
            while [[ $backup_selection != true ]]
            do
                clear -x
                title
                echo -e "${bold}Backup Menu${reset}"
                echo -e "${bold}-----------${reset}"
                echo "1)  Create Backup"
                echo "2)  Delete Backup"
                echo "3)  Restore Backup"
                echo
                echo "0)  Exit"
                read -rt 120 -p "Please select an option by number: " backup_selection || { echo -e "${red}\nFailed to make a selection in time${reset}" ; exit; }
                case $backup_selection in
                    0)
                        echo "Exiting.."
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
                        echo -e "${red}\"$selection\" was not an option, please try agian${reset}"
                        sleep 3
                        continue
                        ;;
                esac
            done
            ;;
            
        # HeavyScript Options
        5)
            while [[ $misc_selection != true ]]
            do
                clear -x
                title
                echo -e "${bold}HeavyScript Options Menu${reset}"
                echo -e "${bold}------------------------${reset}"
                echo "1)  Self Update"
                echo "2)  Choose Branch"
                echo "3)  Add Script to Global Path"
                echo -e "${gray}This will download the one liner, and add it to your global path, you only need to do this once.${reset} "
                echo
                echo "0)  Exit"
                read -rt 120 -p "Please select an option by number: " misc_selection || { echo -e "${red}\nFailed to make a selection in time${reset}" ; exit; }
                case $misc_selection in
                    0)
                        echo "Exiting.."
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
                        echo -e "${blue}\"$selection\"${red} was not an option, please try agian${reset}"
                        sleep 3
                        continue
                        ;;
                esac
            done
            ;;

        # Update Applications
        6)
            script_create
            ;;
        
        # Command to Container / Container Logs
        7)
            while [[ $misc_selection != true ]]
            do
                clear -x
                title
                echo -e "${bold}Command to Container / Container Logs Menu${reset}"
                echo -e "${bold}------------------------------------------${reset}"
                echo "1)  Command to Container"
                echo "2)  Container Logs"
                echo
                echo "0)  Exit"
                read -rt 120 -p "Please select an option by number: " misc_selection || { echo -e "${red}\nFailed to make a selection in time${reset}" ; exit; }
                case $misc_selection in
                    0)
                        echo "Exiting.."
                        exit
                        ;;
                    1)
                        misc_selection=true
                        container_shell_or_logs
                        ;;
                    2)
                        misc_selection=true
                        container_shell_or_logs "logs"
                        ;;
                    *)
                        echo -e "${blue}\"$selection\"${red} was not an option, please try agian${reset}"
                        sleep 3
                        continue
                        ;;
                esac
            done
            ;;
        
        # Patches
        8) 
            # Give users the option to run patch_2212_backups or choose_branch
            while [[ $misc_selection != true ]]
            do
                clear -x
                title
                echo -e "${bold}Patch Menu${reset}"
                echo -e "${bold}----------${reset}"
                echo "1)  Patch 22.12.0 Restore"
                echo -e "${gray}- - Fixes issue on 22.12.0 where restore points were being saved with empty PVC data${reset}"
                echo
                echo "2)  Patch 22.12.0 Backups"
                echo -e "${gray}- - Fixes issue on 22.12.0 where backups would fail on certain applications${reset}"
                echo
                echo "0)  Exit"
                read -rt 120 -p "Please select an option by number: " misc_selection || { echo -e "${red}\nFailed to make a selection in time${reset}" ; exit; }
                case $misc_selection in
                    0)
                        echo "Exiting.."
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
                        echo -e "${blue}\"$selection\"${red} was not an option, please try agian${reset}"
                        sleep 3
                        continue
                        ;;
                esac
            done
            ;;
        *)
            echo -e "${blue}\"$selection\"${red} was not an option, please try agian${reset}"
            sleep 3
            menu
            ;;
    esac
    echo
}
export -f menu
