#!/bin/bash


menu(){
clear -x
title
echo "1)  Help"
echo "2)  List DNS Names"
echo "3)  Mount and Unmount PVC storage"
echo "4)  Create a Backup"
echo "5)  Restore a Backup"
echo "6)  Delete a Backup"
echo "7)  Update HeavyScript"
echo "8)  Update Applications"
echo "9)  Command to Container"
echo
echo "0)  Exit"
read -rt 120 -p "Please select an option by number: " selection || { echo -e "\nFailed to make a selection in time" ; exit; }

case $selection in
    0)
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
        read -rt 120 -p "What is the maximun number of backups you would like?: " number_of_backups || { echo -e "\nFailed to make a selection in time" ; exit; }
        ! [[ $number_of_backups =~ ^[0-9]+$  ]] && echo -e "Error: -b needs to be assigned an interger\n\"""$number_of_backups""\" is not an interger" >&2 && exit
        [[ "$number_of_backups" -le 0 ]] && echo "Error: Number of backups is required to be at least 1" && exit
        ;;
    5)
        restore
        ;;
    6)
        deleteBackup
        ;;
    7)
        self_update
        ;;
    8)
        script_create
        ;;
    9)
        cmd_to_container
        ;;
    *)
        echo "\"$selection\" was not an option, please try agian" && sleep 3 && menu
        ;;
esac
echo
}
export -f menu