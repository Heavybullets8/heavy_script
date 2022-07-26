#!/bin/bash

menu(){
  title
  echo "0  Help"
  echo "1  List DNS Names"
  echo "2  Mount and Unmount PVC storage"
  echo "3  Create a Backup"
  echo "4  Restore a Backup"
  echo "5  Delete a Backup"
  echo "6  Update All Apps"
  read -rt 600 -p "Please select an option by number: " selection

  case $selection in
    0)
        help="true"
        ;;
    1)
        dns="true"
        ;;
    2)
        mount="true"
        ;;
    3)
        read -rt 600 -p "Please type the max number of backups to keep: " number_of_backups
        re='^[0-9]+$'
        number_of_backups=$number_of_backups
        ! [[ $number_of_backups =~ $re  ]] && echo -e "Error: -b needs to be assigned an interger\n\"""$number_of_backups""\" is not an interger" >&2 && exit
        [[ "$number_of_backups" -le 0 ]] && echo "Error: Number of backups is required to be at least 1" && exit
        echo "Generating backup, please be patient for output.."
        backup "$number_of_backups"
      ;;
    4)
        restore="true"
        ;;
    5)
        deleteBackup="true"
        ;;
    6)
        echo ""
        echo "1  Update Apps Excluding likely breaking major changes"
        echo "2  Update Apps Including likely breaking major changes"
        read -rt 600 -p "Please select an option by number: " updateType
        if [[ "$updateType" == "1" ]]; then
            update_apps="true"
        elif [[ "$updateType" == "2" ]]; then
            update_all_apps="true"
        else
            echo "INVALID ENTRY" && exit 1
        fi
        ;;
    *)
        echo "Unknown option" && exit 1
        ;;
  esac
  echo ""
}
export -f menu