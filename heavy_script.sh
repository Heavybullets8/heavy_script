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


# Source all functions and utilities
while IFS= read -r script_file; do
    if [[ "$script_file" == "functions/deploy.sh" ]]; then
        # Ignore the deploy.sh file, it is meant to install the script
        continue
    fi
    # shellcheck source=/dev/null
    source "$script_file"
done < <(find functions utils -name "*.sh" -exec printf '%s\n' {} \;)


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


  # Separate bundled short options
  args=()
  for arg in "$@"; do
    if [[ $arg =~ ^-[srSpvtu]+$ ]]; then
      for opt in $(echo "$arg" | grep -o .); do
        if [[ $opt == "-" ]]; then
          # Ignore the leading dash
          continue
        fi
        args+=("-$opt")
      done
    else
      args+=("$arg")
    fi
  done

  # Replace "$@" with the new "args" array
  set -- "${args[@]}"


# Check for self-update and update the script if required
self_update_handler "${args[@]}"

while [[ "$#" -gt 0 ]]; do
  case $1 in
    app)
      shift # Remove 'app' from the arguments
      app_handler "${args[@]}" # Pass remaining arguments to app_handler
      exit
      ;;
    backup)
      shift # Remove 'backup' from the arguments
      backup_handler "${args[@]}" # Pass remaining arguments to backup_handler
      exit
      ;;
    dns)
      shift # Remove 'dns' from the arguments
      dns_handler "${args[@]}" # Pass remaining arguments to dns_handler
      exit
      ;;
    git)
      shift # Remove 'git' from the arguments
      git_handler "${args[@]}" # Pass remaining arguments to git_handler
      exit
      ;;
    pod)
      shift # Remove 'pod' from the arguments
      pod_handler "${args[@]}" # Pass remaining arguments to pod_handler
      exit
      ;;
    pvc)
      shift # Remove 'mount' from the arguments
      mount_handler "${args[@]}" # Pass remaining arguments to mount_handler
      exit
      ;;
    update)
      shift # Remove 'update' from the arguments
      update_handler "${args[@]}" # Pass remaining arguments to update_handler
      exit
      ;;
    *)
      echo "Unknown command: $1"
      exit 1
      ;;
  esac
done



# Parse script options
while getopts ":si:rb:t:uUpSRv-:" opt
do
    case $opt in
      -)
          case "${OPTARG}" in
             help)
                  help=true
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
