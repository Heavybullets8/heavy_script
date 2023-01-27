#!/bin/bash

# Exit on errors
set -e

# Check user's permissions 
if [[ $(id -u) != 0 ]]; then
    echo "This script must be run as root." >&2
    exit 1
fi

# Define variables
script_name='heavyscript'
script_dir="$HOME/heavy_script"
bin_dir="$HOME/bin"
script_wrapper="$bin_dir/$script_name"

# Check if the script repository already exists
if [[ -d "$script_dir/.git" ]]; then
    echo "The script repository already exists. Do you want to update/reinstall it? [y/n]"
    while true; do
        read -r user_input
        case $user_input in
            [Yy] | [Yy][Ee][Ss])
                echo "Updating $script_name repository..."
                cd "$script_dir"
                git reset --hard &>/dev/null
                git pull --tags
                git checkout "$(git describe --tags "$(git rev-list --tags --max-count=1)")"
                break
                ;;
            [Nn] | [Nn][Oo])
                echo "Exiting the script."
                exit 0
                ;;
            *)
                echo "Invalid input."
                sleep 2
                continue
                ;;
        esac
    done
else
    # Clone the script repository
    echo "Cloning $script_name repository..."
    cd "$HOME"
    git clone -b "$(git describe --tags "$(git rev-list --tags --max-count=1)")" --single-branch "https://github.com/Heavybullets8/heavy_script.git"
fi

# Create the bin directory if it does not exist
if [[ ! -d "$bin_dir" ]]; then
    echo "Creating $bin_dir directory..."
    mkdir "$bin_dir"
fi

# Create the script wrapper if it does not exist
if [[ ! -x "$script_wrapper" ]]; then
    echo "Creating $script_wrapper wrapper..."
    ln -s "$script_dir/bin/$script_name" "$script_wrapper"
fi

# Add $HOME/bin to PATH in .bashrc and .zshrc
for rc_file in .bashrc .zshrc; do
    if ! grep -q "$bin_dir" "$HOME/$rc_file"; then
        echo "Adding $bin_dir to $rc_file..."
        echo "export PATH=$bin_dir:\$PATH" >> "$HOME/$rc_file"
    fi
done

