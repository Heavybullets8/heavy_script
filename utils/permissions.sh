#!/bin/bash


check_root() {
    args=("$@")
    if [[ $EUID -ne 0 ]]; then
        for arg in "${args[@]}"; do
            if [[ $arg == "-h" || $arg == "--help" ]]; then
                return
            fi
        done

        echo -e "${red}Error: ${blue}${args[0]}${red} requires root privileges."
        echo -e "Please run the script with ${blue}sudo${red} or as ${blue}root."
        echo -e "${yellow}Tip: You can re-run the last command with sudo by typing ${blue}sudo !!"
        exit 1 
    fi
}

ensure_sudoers() {
    get_invoking_user() {
        if [[ $EUID -eq 0 ]]; then
            echo "${SUDO_USER:-root}"
        else
            whoami
        fi
    }

    get_user_home() {
        local user_home

        if [[ $EUID -eq 0 ]]; then  # Script is running as root
            # Use SUDO_USER if set, otherwise fall back to root's home
            user_home=$(getent passwd "${SUDO_USER:-root}" | cut -d: -f6)
        else  # Script is run by a regular user
            user_home=$HOME
        fi

        echo "$user_home"
    }


    local user env_keep_exists secure_path_exists TMP_FILE home

    user=$(get_invoking_user)
    home=$(get_user_home)

    # No need to modify sudoers if the script is run as root
    if [[ $user == "root" || $home == "/root" || $script_path == "/root/heavy_script" ]]; then
        return 0
    fi

    local script_location="$home/bin"

    if [[ ! -f "$script_location/heavyscript" ]]; then
        return 0
    fi


    # Check if specific entries already exist in the sudoers file
    env_keep_exists=$(grep -c "Defaults:$user env_keep+=\"PATH\"" /etc/sudoers)
    secure_path_exists=$(grep -c "Defaults:$user secure_path=\"/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin:$script_location\"" /etc/sudoers)

    # Exit the function if no changes are needed
    if [[ $env_keep_exists -gt 0 && $secure_path_exists -gt 0 ]]; then
        echo "No updates needed for sudoers file."
        return 0
    fi

    # Create a temporary file only if changes are needed
    TMP_FILE=$(mktemp)
    
    # Ensure cleanup on exit
    trap 'rm -f "$TMP_FILE"' EXIT

    # Copy current sudoers to temp
    cat /etc/sudoers > "$TMP_FILE"

    # Append new lines only if they don't already exist
    if [[ $env_keep_exists -eq 0 ]]; then
        echo "Defaults:$user env_keep+=\"PATH\"" >> "$TMP_FILE"
    fi

    if [[ $secure_path_exists -eq 0 ]]; then
        echo "Defaults:$user secure_path=\"/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin:$script_location\"" >> "$TMP_FILE"
    fi

    # Check for syntax errors with visudo
    if visudo -c -f "$TMP_FILE"; then
        # If the temp file is okay, safely copy it to the actual sudoers file
        sudo cp "$TMP_FILE" /etc/sudoers
        echo "Sudoers file has been updated successfully."
    else
        echo "Error found in sudoers temp file. No changes were made."
    fi
}




