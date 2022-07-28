#!/bin/bash

# cd to script, this ensures the script can find the source scripts below, even when ran from a seperate directory
script=$(readlink -f "$0")
script_path=$(dirname "$script")
script_name="heavy_script.sh"
cd "$script_path" || { echo "Error: Failed to change to script directory" ; exit ; } 


# shellcheck source=functions/backup.sh
source functions/backup.sh
# shellcheck source=functions/dns.sh
source functions/dns.sh
# shellcheck source=functions/menu.sh
source functions/menu.sh
# shellcheck source=functions/misc.sh
source functions/misc.sh
# shellcheck source=functions/mount.sh
source functions/mount.sh
# shellcheck source=functions/self_update.sh
source functions/self_update.sh
# shellcheck source=functions/update_apps.sh
source functions/update_apps.sh


#If no argument is passed, kill the script.
[[ -z "$*" || "-" == "$*" || "--" == "$*"  ]] && menu


# Parse script options
while getopts ":sirb:t:uUpSRv-:" opt
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
          restore)
                  restore="true"
                  ;;
            mount)
                  mount="true"
                  ;;
    delete-backup)
                  deleteBackup="true"
                  ;;
                *)
                  echo -e "Invalid Option \"--$OPTARG\"\n" && help
                  exit
                  ;;
          esac
          ;;
      :)
         echo -e "Option: \"-$OPTARG\" requires an argument\n" && help
         exit
         ;;
      b)
        number_of_backups=$OPTARG
        ! [[ $OPTARG =~ ^[0-9]+$  ]] && echo -e "Error: -b needs to be assigned an interger\n\"""$number_of_backups""\" is not an interger" >&2 && exit
        [[ "$number_of_backups" -le 0 ]] && echo "Error: Number of backups is required to be at least 1" && exit
        backup="true"
        ;;
      r)
        rollback="true"
        ;;
      i)
        # Check next positional parameter
        eval nextopt=${!OPTIND}
        # existing or starting with dash?
        if [[ -n $nextopt && $nextopt != -* ]] ; then
            OPTIND=$((OPTIND + 1))
            ignore+=("$nextopt")
        else
            echo "Option: \"-i\" requires an argument"
            exit
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
      \?)
        echo -e "Invalid Option \"-$OPTARG\"\n" && help
        exit
        ;;
      *)
        echo -e "Invalid Option \"-$OPTARG\"\n" && help
        exit
        ;;
    esac
done



#exit if incompatable functions are called 
[[ "$update_all_apps" == "true" && "$update_apps" == "true" ]] && echo -e "-U and -u cannot BOTH be called" && exit

#Continue to call functions in specific order
[[ "$help" == "true" ]] && help
[[ "$self_update" == "true" ]] && self_update
[[ "$deleteBackup" == "true" ]] && deleteBackup && exit
[[ "$dns" == "true" ]] && dns && exit
[[ "$restore" == "true" ]] && restore && exit
[[ "$mount" == "true" ]] && mount && exit
if [[ "$backup" == "true" && "$sync" == "true" ]]; then # Run backup and sync at the same time
    echo "🅃 🄰 🅂 🄺 🅂 :"
    echo -e "-Backing up ix-applications dataset\n-Syncing catalog(s)"
    echo -e "This can take a LONG time, please wait for both output..\n"
    backup &
    sync &
    wait
fi
[[ "$backup" == "true" && -z "$sync" ]] && echo "Backing up \"ix-applications\" dataset, please wait.." && backup 
[[ "$sync" == "true" && -z "$backup" ]] && echo "Syncing catalogs, this takes a LONG time, please wait.." && sync 
[[ "$update_all_apps" == "true" || "$update_apps" == "true" ]] && commander
[[ "$prune" == "true" ]] && prune
