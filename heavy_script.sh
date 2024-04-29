#!/bin/bash

declare -x no_config=false
declare -x no_self_update=false
declare -x self_update=false
declare -x major_self_update=false
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

# Ensure sudoers file contains the necessary configuration
if [[ $EUID -eq 0 ]]; then
    ensure_sudoers
fi

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

if remove_self_update_args; then
    self_update=true
fi

if remove_force_update_args; then
    major_self_update=true
fi

if remove_no_self_update_args; then
    no_self_update=true
fi

if remove_no_config_args; then
    no_config=true
fi

# Run the self update function if the script has not already been updated
if [[ $no_self_update == false ]]; then
    self_update_handler "${args[@]}"
fi

# If no arguments are passed, the first argument is an empty string, '-', or '--', open the menu function.
if [[ "${#args[@]}" -eq 0 || "${args[0]}" =~ ^(-{1,2})?$ ]]; then
    menu
    exit
fi

case "${args[0]}" in
    app)
        check_root "${args[@]}"
        app_handler "${args[@]:1}"
        ;;
    backup)
        check_root "${args[@]}"
        backup_handler "${args[@]:1}"
        ;;
    dns)
        check_root "${args[@]}"
        dns_handler "${args[@]:1}" 
        ;;
    enable)
        check_root "${args[@]}"
        enable_handler "${args[@]:1}" 
        ;;
    git)
        git_handler "${args[@]:1}"
        ;;
    pod)
        check_root "${args[@]}"
        pod_handler "${args[@]:1}"
        ;;
    pvc)
        check_root "${args[@]}"
        pvc_handler "${args[@]:1}" 
        ;;
    update)
        check_root "${args[@]}"
        update_handler "${args[@]:1}" 
        ;;
    sync)
        check_root "${args[@]}"
        sync_handler "${args[@]:1}" 
        ;;
    prune)
        check_root "${args[@]}"
        prune_handler "${args[@]:1}"
        ;;
    -h|--help|help)
        main_help
        ;;
    *)
        echo "Unknown command: $1"
        exit 1
        ;;
esac
