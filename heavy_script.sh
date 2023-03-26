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

while [[ "${#args[@]}" -gt 0 ]]; do
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
