#!/bin/bash

# Exit on errors
set -e

# Check user's permissions 
if [[ $(id -u) != 0 ]]; then
    echo "This script must be run as root." >&2
    exit 1
fi

# Define a function to update the repository
update_repo() {
    local script_dir="$1"
    local success=false
    cd "$script_dir"

    git reset --hard &>/dev/null
    if git pull --tags &>/dev/null; then
        echo "Successfully pulled the latest tags."
        success=true
    else
        echo "Failed to pull the latest tags."
    fi

    if git checkout "$(git describe --tags "$(git rev-list --tags --max-count=1)")" &>/dev/null; then
        echo "Successfully checked out the latest release."
        success=true
    else
        echo "Failed to check out the latest release."
    fi

    return $success
}

# Define variables
script_name='heavyscript'
script_dir="$HOME/heavy_script"
bin_dir="$HOME/bin"
script_wrapper="$bin_dir/$script_name"


# Check if the script repository already exists
if [[ -d "$script_dir" ]]; then
    echo "The $script_name repository already exists."
    if [[ -d "$script_dir/.git" ]]; then
        echo "Reinstalling $script_name repository..."
        if update_repo "$script_dir"; then
            echo "Successfully updated the repository"
        else
            echo "Failed to reinstall the repository"
            exit 1
        fi
    else
        # Convert the directory into a git repository
        echo "Converting it into a git repository..."
        cd "$script_dir"
        git init
        git remote add origin "https://github.com/Heavybullets8/heavy_script.git"
        if update_repo "$script_dir"; then
            echo "Successfully updated the repository"
        else
            echo "Failed to update the repository"
            exit 1
        fi
    fi
else
    # Clone the script repository
    echo "Cloning $script_name repository..."
    cd "$HOME"
    git clone "https://github.com/Heavybullets8/heavy_script.git"
    cd heavy_script
    if update_repo "$script_dir"; then
        echo "Successfully updated the repository"
    else
        echo "Failed to update the repository"
        exit 1
    fi
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
    if [[ ! -f "$HOME/$rc_file" ]]; then
        echo "Creating $HOME/$rc_file file..."
        touch "$HOME/$rc_file"
    fi

    if ! grep -q "$bin_dir" "$HOME/$rc_file"; then
        echo "Adding $bin_dir to $rc_file..."
        echo "export PATH=$bin_dir:\$PATH" >> "$HOME/$rc_file"
    fi
done

# Give the script executable permissions
chmod +x "$script_dir/bin/$script_name"
