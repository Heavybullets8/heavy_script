#!/bin/bash


menu(){
    clear -x
    title
    echo "Available Utilities"
    echo "-------------------"
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
    read -rt 120 -p "Please select an option by number: " selection || { echo -e "\nFailed to make a selection in time" ; exit; }

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
                echo "Backup Menu"
                echo "-----------"
                echo "1)  Create Backup"
                echo "2)  Delete Backup"
                echo "3)  Restore Backup"
                echo
                echo "0)  Exit"
                read -rt 120 -p "Please select an option by number: " backup_selection || { echo -e "\nFailed to make a selection in time" ; exit; }
                case $backup_selection in
                    0)
                        echo "Exiting.."
                        exit
                        ;;
                    1)
                        read -rt 120 -p "What is the maximun number of backups you would like?: " number_of_backups || { echo -e "\nFailed to make a selection in time" ; exit; }
                        ! [[ $number_of_backups =~ ^[0-9]+$  ]] && echo -e "Error: The input must be an interger\n\"""$number_of_backups""\" is not an interger" >&2 && exit
                        [[ "$number_of_backups" -le 0 ]] && echo "Error: Number of backups is required to be at least 1" && exit
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
                        echo "\"$selection\" was not an option, please try agian" && sleep 3 && continue
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
                echo "Misc Menu"
                echo "-----------"
                echo "1)  Self Update"
                echo "2)  Choose Branch"
                echo
                echo "0)  Exit"
                read -rt 120 -p "Please select an option by number: " misc_selection || { echo -e "\nFailed to make a selection in time" ; exit; }
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
                    *)
                        echo "\"$selection\" was not an option, please try agian" && sleep 3 && continue
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
                echo "Misc Menu"
                echo "-----------"
                echo "1)  Command to Container"
                echo "2)  Container Logs"
                echo
                echo "0)  Exit"
                read -rt 120 -p "Please select an option by number: " misc_selection || { echo -e "\nFailed to make a selection in time" ; exit; }
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
                        echo "\"$selection\" was not an option, please try agian" && sleep 3 && continue
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
                echo "Misc Menu"
                echo "-----------"
                echo "1)  Patch 22.12.0 Restore"
                echo "- This will fix the issue with the 22.12.0 patch where backups are created with empty PVC data"
                echo
                echo "2)  Patch 22.12.0 Backups"
                echo "- This will fix the issue with the 22.12.0 patch where backups fail on certain applications"
                echo
                echo "0)  Exit"
                read -rt 120 -p "Please select an option by number: " misc_selection || { echo -e "\nFailed to make a selection in time" ; exit; }
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
                        choose_branch
                        ;;
                    *)
                        echo "\"$selection\" was not an option, please try agian" && sleep 3 && continue
                        ;;
                esac
            done
            ;;
        *)
            echo "\"$selection\" was not an option, please try agian" && sleep 3 && menu
            ;;
    esac
    echo
}
export -f menu
