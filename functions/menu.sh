#!/bin/bash

menu(){
  clear -x
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
        script=$(readlink -f "$0")
        script_path=$(dirname "$script")
        script_name="heavy_script.sh"
        cd "$script_path" || exit
        clear -x
        echo "Choose your update options "
        echo
        echo "-U | Update all applications, ignores versions"
        echo "-u | Update all applications, does not update Major releases"
        echo "-b | Back-up your ix-applications dataset, specify a number after -b"
        echo "-i | Add application to ignore list, one by one, see example below."
        echo "-r | Roll-back applications if they fail to update"
        echo "-S | Shutdown applications prior to updating"
        echo "-v | verbose output"
        echo "-t | Set a custom timeout in seconds when checking if either an App or Mountpoint correctly Started, Stopped or (un)Mounted. Defaults to 500 seconds"
        echo "-s | sync catalog"
        echo "-p | Prune unused/old docker images"
        echo 
        echo "Example: -u 3 -b 14 -rSvsp -i nextcloud"

        read -rt 600 -p "Please type the flags you wish, with options above: " update_selection
        exec bash "$script_name" "${update_selection[@]}"

        ;;
    *)
        echo "Unknown option" && exit 1
        ;;
  esac
  echo ""
}
export -f menu