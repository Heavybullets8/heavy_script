#!/bin/bash


# cd to script, this ensures the script can find the source scripts below, even when ran from a seperate directory
script=$(readlink -f "$0")
script_path=$(dirname "$script")
script_name="heavy_script.sh"
cd "$script_path" || { echo "Error: Failed to change to script directory" ; exit ; } 

# Get the name of the latest tag
current_tag=$(git describe --tags --abbrev=0)

# Check if the current version is a branch or a tag
current_version=$(git rev-parse --abbrev-ref HEAD)
if [[ "$current_version" == "HEAD" ]]; then
    # The current version is a tag, assign the name of the current tag to the hs_version variable
    hs_version=${current_tag}
else
    # The current version is a branch, assign the name of the current branch to the hs_version variable
    hs_version=${current_version}
fi

# Source all the functions and utilities
find functions utils -name "*.sh" | while read -r script_file; do
    if [[ "$script_file" == "functions/deploy.sh" ]]; then
        # Ignore the deploy.sh file, it is meant to install the script
        continue
    fi
    # shellcheck source=/dev/null
    source "$script_file"
done


# Source necessary function files
source functions/dns/handler.sh

# Main script
while [[ "$#" -gt 0 ]]; do
  case $1 in
    dns)
      shift # Remove 'dns' from the arguments
      dns_handler "$@" # Pass remaining arguments to dns_handler
      break # Exit the loop
      ;;
    *)
      echo "Unknown command: $1"
      exit 1
      ;;
  esac
  shift # Remove the processed argument
done




# colors
reset='\033[0m'
red='\033[0;31m'
yellow='\033[1;33m'
green='\033[0;32m'
blue='\033[0;34m'
bold='\033[1m'
gray='\033[38;5;7m'


#If no argument is passed, open menu function.
if [[ -z "$*" || "-" == "$*" || "--" == "$*"  ]]; then
    menu
fi

# Parse script options
while getopts ":si:rb:t:uUpSRv-:" opt
do
    case $opt in
      -)
          case "${OPTARG}" in
             help)
                  help=true
                  ;;
      self-update)
                  self_update=true
                  ;;
              dns)
                  dns=true
                  ;;
              cmd)
                  cmd=true
                  ;;
          restore)
                  restore=true
                  ;;
            mount)
                  mount=true
                  ;;
    delete-backup)
                  deleteBackup=true
                  ;;
       ignore-img)
                  ignore_image_update=true
                  ;;
              logs)
                  logs=true
                  ;;
         start-app)
                  start_app=true
                  ;;
        delete-app)
                  delete_app=true
                  ;;
          stop-app)
                  stop_app=true
                  ;;
       restart-app)
                  restart_app=true
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
        if ! [[ $OPTARG =~ ^[0-9]+$  ]]; then
            echo -e "Error: -b needs to be assigned an interger\n\"""$number_of_backups""\" is not an interger" >&2
            exit
        fi
        if [[ "$number_of_backups" -le 0 ]]; then
            echo "Error: Number of backups is required to be at least 1"
            exit
        fi
        ;;
      r)
        rollback=true
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
        if ! [[ $timeout =~ ^[0-9]+$ ]]; then
            echo -e "Error: -t needs to be assigned an interger\n\"""$timeout""\" is not an interger" >&2
            exit
        fi
        ;;
      s)
        sync=true
        ;;
      U)
        update_all_apps=true
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
        update_apps=true
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
        stop_before_update=true
        ;;
      p)
        prune=true
        ;;
      v)
        verbose=true
        ;;
      *)
        echo -e "Invalid Option \"-$OPTARG\"\n"
        help
        ;;
    esac
done


### exit if incompatable functions are called ### 
if [[ "$update_all_apps" == true && "$update_apps" == true ]]; then
    echo -e "-U and -u cannot BOTH be called"
    exit 1
fi

### Continue to call functions in specific order ###
if [[ "$self_update" == true ]]; then 
    self_update
fi

if [[ "$help" == true ]]; then
    help
fi

if [[ "$delete_app" == true ]]; then
    delete_app_prompt
    exit
fi

if [[ "$stop_app" == true ]]; then
    stop_app_prompt
    exit
fi

if [[ "$start_app" == true ]]; then
    start_app_prompt
    exit
fi

if [[ "$restart_app" == true ]]; then
    restart_app_prompt
    exit
fi

if [[ "$cmd" == true || "$logs" == true ]]; then
    container_shell_or_logs
    exit
fi

if [[ "$deleteBackup" == true ]]; then 
    deleteBackup
    exit
fi

if [[ "$dns" == true ]]; then
    dns
    exit
fi

if [[ "$restore" == true ]]; then
    restore
    exit
fi

if [[ "$mount" == true ]]; then 
    mount
    exit
fi

if [[ "$number_of_backups" -gt 1 && "$sync" == true ]]; then # Run backup and sync at the same time
    echo "🅃 🄰 🅂 🄺 🅂 :"
    echo -e "-Backing up ix-applications dataset\n-Syncing catalog(s)"
    echo -e "Please wait for output from both tasks..\n\n"
    backup &
    sync &
    wait
elif [[ "$number_of_backups" -gt 1 ]]; then # If only backup is true, run it
    echo "🅃 🄰 🅂 🄺 :"
    echo -e "-Backing up ix-applications dataset\nPlease wait..\n\n"
    backup
elif [[ "$sync" == true ]]; then # If only sync is true, run it
    echo "🅃 🄰 🅂 🄺 :"
    echo -e "Syncing Catalog(s)\nThis can take a few minutes, please wait..\n\n"
    sync
fi

if [[ "$update_all_apps" == true || "$update_apps" == true ]]; then 
    commander
fi

if [[ "$prune" == true ]]; then
    prune 
fi
