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
    find_user_and_home() {
        local script_path="$1"
        while IFS=: read -r username _ _ _ _ home _; do
            if [[ "$script_path" == "$home"* ]]; then
                echo "$username|$home"
                return 0
            fi
        done < <(getent passwd | grep -Ev "nonexistent|nologin$")
    }
    
    local user env_keep_exists secure_path_exists TMP_FILE home

    # Capture output, which contains both user and home
    output=$(find_user_and_home "$script_path")

    # Split output into user and home
    IFS='|' read -r user home <<< "$output"

    # No need to modify sudoers if the script is run as root
    if [[ $user == "root" || $home == "/root" || $script_path == "/root/heavy_script" || -z $home || -z $user ]]; then
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




