#!/bin/bash

# colors
reset='\033[0m'
red='\033[0;31m'
yellow='\033[1;33m'
green='\033[0;32m'
blue='\033[0;34m'


# Check user's permissions
if [[ $(id -u) != 0 ]]; then
    echo -e "${red}This script must be run as root.${reset}" >&2
    exit 1
fi

# Check if user has a home
if [[ -z "$HOME" || $HOME == "/nonexistent" ]]; then
    echo -e "${red}This script requires a home directory.${reset}" >&2
    exit 1
fi


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


# Define variables
script_name='heavyscript'
script_dir="$HOME/heavy_script"
bin_dir="$HOME/bin"
script_wrapper="$bin_dir/$script_name"

main() {
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
        cd "$HOME" || exit 1
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

    # Create the bin directory if it does not exist
    if [[ ! -d "$bin_dir" ]]; then
        echo -e "${blue}Creating $bin_dir directory...${reset}"
        mkdir "$bin_dir"
    fi

    # Create symlink inside bin, to the script
    echo -e "${blue}Creating $script_wrapper wrapper...${reset}"
    ln -sf "$script_dir/bin/$script_name" "$script_wrapper"
    chmod +x "$script_dir/bin/$script_name"

    echo

    # Add $HOME/bin to PATH in .bashrc and .zshrc
    for rc_file in .bashrc .zshrc; do
        if [[ ! -f "$HOME/$rc_file" ]]; then
            echo -e "${blue}Creating $HOME/$rc_file file...${reset}"
            touch "$HOME/$rc_file"
        fi

        if ! grep -q "$bin_dir" "$HOME/$rc_file"; then
            echo -e "${blue}Adding $bin_dir to $rc_file...${reset}"
            echo "export PATH=$bin_dir:\$PATH" >> "$HOME/$rc_file"
        fi
    done

    echo
    echo -e "${green}Successfully installed ${blue}$script_name${reset}"
    echo
}

main
