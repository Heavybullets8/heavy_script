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
echo "5)  Update HeavyScript"
echo "6)  Update Applications"
echo "7)  Command to Container"
echo "8)  Patch 22.12.0"
echo "9)  Patch 22.12.0 (2)"
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
    2)
        dns 
        ;;
    3)
        mount
        ;;
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
        
    5)
        self_update
        ;;
    6)
        script_create
        ;;
    7)
        cmd_to_container
        ;;
    8)
        patch_2212_backups
        ;;
    9) 
        patch_2212_backups2
        ;;
    *)
        echo "\"$selection\" was not an option, please try agian" && sleep 3 && menu
        ;;
esac
echo
}
export -f menu