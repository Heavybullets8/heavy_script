#!/bin/bash

declare -x no_config=false
declare -x script
declare -x script_path
declare -x script_name
declare -x current_tag
declare -x current_version
declare -x hs_version
# colors
declare -x reset='\033[0m'
declare -x red='\033[0;31m'
declare -x yellow='\033[1;33m'
declare -x green='\033[0;32m'
declare -x blue='\033[0;34m'
declare -x bold='\033[1m'
declare -x gray='\033[38;5;7m'

# cd to script, this ensures the script can find the source scripts below, even when ran from a separate directory
script=$(readlink -f "$0")
script_path=$(dirname "$script")
script_name="heavy_script.sh"
cd "$script_path" || { echo "Error: Failed to change to script directory"; exit; } 

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

# generate the config.ini file if it does not exist
generate_config_ini

# Separate bundled short options
args=()
for arg in "$@"; do
    if [[ $arg =~ ^-[aIprsxUv]+$ ]]; then
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

if check_no_config;then
    no_config=true
    mapfile -t args < <(remove_no_config_args "${args[@]}")
fi

# Check for self-update and update the script if required
self_update_handler "${args[@]}"

# Unset self-update arguments/--no-self-update/--major
mapfile -t args < <(remove_no_self_update_args "${args[@]}")
mapfile -t args < <(remove_self_update_args "${args[@]}")
mapfile -t args < <(remove_force_update_args "${args[@]}")

# If no arguments are passed, the first argument is an empty string, '-', or '--', open the menu function.
if [[ "${#args[@]}" -eq 0 || "${args[0]}" =~ ^(-{1,2})?$ ]]; then
    menu
    exit
fi



case $1 in
    app)
        app_handler "${args[@]:1}" # Pass remaining arguments to app_handler
        ;;
    backup)
        backup_handler "${args[@]:1}" # Pass remaining arguments to backup_handler
        ;;
    dns)
        dns_handler "${args[@]:1}" # Pass remaining arguments to dns_handler
        ;;
    enable)
        enable_handler "${args[@]:1}" # Pass remaining arguments to enable_handler
        ;;
    git)
        git_handler "${args[@]:1}" # Pass remaining arguments to git_handler
        ;;
    pod)
        pod_handler "${args[@]:1}" # Pass remaining arguments to pod_handler
        ;;
    pvc)
        pvc_handler "${args[@]:1}" # Pass remaining arguments to mount_handler
        ;;
    update)
        update_handler "${args[@]:1}" # Pass remaining arguments to update_handler
        ;;
    sync)
        sync_handler "${args[@]:1}" # Pass remaining arguments to sync_handler
        ;;
    prune)
        prune_handler "${args[@]:1}" # Pass remaining arguments to prune_handler
        ;;
    -h|--help|help)
        main_help
        ;;
    *)
        echo "Unknown command: $1"
        exit 1
        ;;
esac

