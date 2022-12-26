#!/bin/bash


# cd to script, this ensures the script can find the source scripts below, even when ran from a seperate directory
script=$(readlink -f "$0")
script_path=$(dirname "$script")
script_name="heavy_script.sh"
cd "$script_path" || { echo "Error: Failed to change to script directory" ; exit ; } 

#Version
hs_version=$(git describe --tags)

source functions/backup.sh
source functions/dns.sh
source functions/menu.sh
source functions/misc.sh
source functions/mount.sh
source functions/self_update.sh
source functions/update_apps.sh
source functions/cmd_to_container.sh
source functions/script_create.sh


#If no argument is passed, kill the script.
[[ -z "$*" || "-" == "$*" || "--" == "$*"  ]] && menu


# Parse script options
while getopts ":si:rb:t:uUpSRv-:" opt
do
    case $opt in
      -)
          case "${OPTARG}" in
             help)
                  help="true"
                  ;;
      self-update)
                  self_update="true"
                  ;;
              dns)
                  dns="true"
                  ;;
              cmd)
                  cmd="true"
                  ;;
          restore)
                  restore="true"
                  ;;
            mount)
                  mount="true"
                  ;;
    delete-backup)
                  deleteBackup="true"
                  ;;
       ignore-img)
                  ignore_image_update="true"
                  ;;
                *)
                  echo -e "Invalid Option \"--$OPTARG\"\n"
                  help
                  ;;
          esac
          ;;
      :)
         echo -e "Option: \"-$OPTARG\" requires an argument\n"
         help
         ;;
      b)
        number_of_backups=$OPTARG
        ! [[ $OPTARG =~ ^[0-9]+$  ]] && echo -e "Error: -b needs to be assigned an interger\n\"""$number_of_backups""\" is not an interger" >&2 && exit
        [[ "$number_of_backups" -le 0 ]] && echo "Error: Number of backups is required to be at least 1" && exit
        ;;
      r)
        rollback="true"
        ;;
      i)
        if ! [[ $OPTARG =~ ^[a-zA-Z]([-a-zA-Z0-9]*[a-zA-Z0-9])?$ ]]; then # Using case insensitive version of the regex used by Truenas Scale
            echo -e "Error: \"$OPTARG\" is not a possible option for an application name"
            exit
        else
            ignore+=("$OPTARG")
        fi
        ;;
      t)
        timeout=$OPTARG
        ! [[ $timeout =~ ^[0-9]+$ ]] && echo -e "Error: -t needs to be assigned an interger\n\"""$timeout""\" is not an interger" >&2 && exit
        ;;
      s)
        sync="true"
        ;;
      U)
        update_all_apps="true"
        # Check next positional parameter
        eval nextopt=${!OPTIND}
        # existing or starting with dash?
        if [[ -n $nextopt && $nextopt != -* ]] ; then
            OPTIND=$((OPTIND + 1))
            update_limit="$nextopt"
        else
            update_limit=1
        fi        
        ;;
      u)
        update_apps="true"
        # Check next positional parameter
        eval nextopt=${!OPTIND}
        # existing or starting with dash?
        if [[ -n $nextopt && $nextopt != -* ]] ; then
            OPTIND=$((OPTIND + 1))
            update_limit="$nextopt"
        else
            update_limit=1
        fi
        ;;
      S)
        stop_before_update="true"
        ;;
      p)
        prune="true"
        ;;
      v)
        verbose="true"
        ;;
      *)
        echo -e "Invalid Option \"-$OPTARG\"\n"
        help
        ;;
    esac
done


#exit if incompatable functions are called 
[[ "$update_all_apps" == "true" && "$update_apps" == "true" ]] && echo -e "-U and -u cannot BOTH be called" && exit

#Continue to call functions in specific order
[[ "$self_update" == "true" ]] && self_update
[[ "$help" == "true" ]] && help
[[ "$cmd" == "true" ]] && cmd_to_container && exit
[[ "$deleteBackup" == "true" ]] && deleteBackup && exit
[[ "$dns" == "true" ]] && dns && exit
[[ "$restore" == "true" ]] && restore && exit
[[ "$mount" == "true" ]] && mount && exit
if [[ "$number_of_backups" -gt 1 && "$sync" == "true" ]]; then # Run backup and sync at the same time
    echo "🅃 🄰 🅂 🄺 🅂 :"
    echo -e "-Backing up ix-applications Dataset\n-Syncing catalog(s)"
    echo -e "This can take a LONG time, Please Wait For Both Output..\n\n"
    backup &
    sync &
    wait
elif [[ "$number_of_backups" -gt 1 && -z "$sync" ]]; then # If only backup is true, run it
    echo "🅃 🄰 🅂 🄺 :"
    echo -e "-Backing up \"ix-applications\" Dataset\nPlease Wait..\n\n"
    backup
elif [[ "$sync" == "true" && -z "$number_of_backups" ]]; then # If only sync is true, run it
    echo "🅃 🄰 🅂 🄺 :"
    echo -e "Syncing Catalog(s)\nThis Takes a LONG Time, Please Wait..\n\n"
    sync
fi
[[ "$update_all_apps" == "true" || "$update_apps" == "true" ]] && commander
[[ "$prune" == "true" ]] && prune 
exit 0
