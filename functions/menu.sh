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
read -rt 120 -p "Please select an option by number: " selection

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
        read -rt 120 -p "What is the maximun number of backups you would like?: " number_of_backups || echo "Failed to make a selection"
        backup="true"
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
