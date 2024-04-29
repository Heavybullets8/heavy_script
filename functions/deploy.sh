#!/bin/bash

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

get_invoking_user() {
    if [[ $EUID -eq 0 ]]; then  # Script is running as root
        # Use SUDO_USER if set, otherwise fall back to root
        echo "${SUDO_USER:-root}"
    else  # Script is run by a regular user
        whoami
    fi
}

update_repo() {
    local script_dir="$1"
    cd "$script_dir" || return 1
    git reset --hard &>/dev/null
    git fetch --tags &>/dev/null
    echo
    echo -e "${blue}Checking out the latest release...${reset}"
    if ! git checkout --force "$(git describe --tags "$(git rev-list --tags --max-count=1)")" &>/dev/null; then
        echo "${red}Failed to check out the latest release.${reset}"
        return 1
    else
        echo -e "${green}Successfully checked out the latest release.${reset}"
        return 0
    fi
}

ensure_sudoers() {
    local  env_keep_exists secure_path_exists TMP_FILE
    local  user="$1"
    local  user_bin_dir="$2/bin"

    # Check if specific entries already exist in the sudoers file
    env_keep_exists=$(grep -c "Defaults:$user env_keep+=\"PATH\"" /etc/sudoers)
    secure_path_exists=$(grep -c "Defaults:$user secure_path=\"/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin:$user_bin_dir\"" /etc/sudoers)

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
        echo "Defaults:$user secure_path=\"/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin:$user_bin_dir\"" >> "$TMP_FILE"
    fi

    # Check for syntax errors with visudo
    if visudo -c -f "$TMP_FILE"; then
        # If the temp file is okay, safely copy it to the actual sudoers file
        sudo cp "$TMP_FILE" /etc/sudoers
        echo -e "${green}Sudoers file has been updated successfully.${reset}\n"
    else
        echo -e "${red}Error found in sudoers temp file. No changes were made.${reset}"
    fi
}

# colors
reset='\033[0m'
red='\033[0;31m'
yellow='\033[1;33m'
green='\033[0;32m'
blue='\033[0;34m'

# Define variables
USER_HOME=$(get_user_home)
script_name='heavyscript'
script_dir="$USER_HOME/heavy_script"
user_bin_dir="$USER_HOME/bin"
user_script_wrapper="$user_bin_dir/$script_name"
invoking_user=$(get_invoking_user)

main() {
    # Check if user has a home
    if [[ -z "$USER_HOME" || $USER_HOME == "/nonexistent" ]]; then
        echo -e "${red}This script requires a home directory.${reset}" >&2
        echo -e "${red}Please create a home directory for the user.${reset}" >&2
        echo -e "${red}You can do so under the credentials tab in the Truenas SCALE GUI${reset}" >&2
        exit 1
    fi

    # Check if the script repository already exists
    if [[ -d "$script_dir" ]]; then
        echo -e "${yellow}The ${blue}$script_name${yellow} repository already exists.${reset}"
        if [[ -d "$script_dir/.git" ]]; then
            echo -e "${blue}Reinstalling $script_name repository...${reset}"
            if ! update_repo "$script_dir"; then
                echo -e "${red}Failed to reinstall the repository${reset}"
                exit 1
            else
                echo -e "${green}Successfully reinstalled the repository${reset}"
            fi
        else
            # Convert the directory into a git repository
            echo -e "${blue}Converting it into a git repository...${reset}"
            cd "$script_dir" || exit 1
            git init
            git remote add origin "https://github.com/Heavybullets8/heavy_script.git"
            if ! update_repo "$script_dir"; then
                echo "${red}Failed to convert to git repository${reset}"
                exit 1
            else
                echo -e "${green}Successfully converted to git repository${reset}"
            fi
        fi
    else
        # Clone the script repository
        echo -e "${blue}Cloning $script_name repository...${reset}"
        cd "$USER_HOME" || exit 1
        if ! git clone "https://github.com/Heavybullets8/heavy_script.git" &>/dev/null; then
            echo -e "${red}Failed to clone the repository${reset}"
            exit 1
        else
            echo -e "${green}Successfully cloned the repository${reset}"
        fi

        cd "$script_dir" || exit 1
        if ! update_repo "$script_dir"; then
            exit 1
        fi
    fi

    echo

    # Create the user's bin directory if it does not exist
    if [[ ! -d "$user_bin_dir" ]]; then
        echo -e "${blue}Creating $user_bin_dir directory...${reset}"
        mkdir "$user_bin_dir"
    fi

    # Create symlink inside user's bin only
    echo -e "${blue}Creating $user_script_wrapper wrapper...${reset}"
    ln -sf "$script_dir/bin/$script_name" "$user_script_wrapper"
    chmod +x "$script_dir/bin/$script_name"


    echo

    if [[ $EUID -eq 0 && -n $SUDO_USER ]]; then
        echo -e "${blue}Adding $invoking_user and $USER_HOME to sudoers...${reset}"
        ensure_sudoers "$invoking_user" "$USER_HOME"
    fi
    
    echo

    # Add $USER_HOME/bin to PATH in .bashrc and .zshrc
    for rc_file in .bashrc .zshrc; do
        if [[ ! -f "$USER_HOME/$rc_file" ]]; then
            echo -e "${blue}Creating $USER_HOME/$rc_file file...${reset}"
            touch "$USER_HOME/$rc_file"
        fi

        if ! grep -q "$user_bin_dir" "$USER_HOME/$rc_file"; then
            echo -e "${blue}Adding $user_bin_dir to $USER_HOME/$rc_file...${reset}"
            echo "export PATH=$user_bin_dir:\$PATH" >> "$USER_HOME/$rc_file"
        fi
    done

    if [[ $EUID -eq 0 && -n $SUDO_USER ]]; then
        echo -e "${green}Changing ownership of HeavyScript to ${blue}$invoking_user${green}...${reset}"
        chown -R "$invoking_user" "$script_dir"
        chown "$invoking_user" "$user_bin_dir/$script_name"
    fi

    echo
    echo -e "${green}Successfully installed ${blue}HeavyScript${green} to ${blue}$script_dir${reset}"
    echo -e "${green}Your example cronjob:${reset}"
    echo -e "${blue}bash $script_dir/heavy_script.sh update${reset}"
    echo
}

main