#!/bin/bash


# Check user's permissions 
if [[ $(id -u) != 0 ]]; then
    echo "This script must be run as root." >&2
    exit 1
fi

update_repo() {
    local script_dir="$1"
    cd "$script_dir" || return 1
    git reset --hard &>/dev/null
    git fetch --tags &>/dev/null
    if ! git checkout --force "$(git describe --tags "$(git rev-list --tags --max-count=1)")" &>/dev/null; then
        echo "Failed to check out the latest release."
        return 1
    fi
    echo "Successfully updated the repository"
    return 0
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
        if ! update_repo "$script_dir"; then
            echo "Failed to reinstall the repository"
            exit 1
        fi
    else
        # Convert the directory into a git repository
        echo "Converting it into a git repository..."
        cd "$script_dir" || exit 1
        git init
        git remote add origin "https://github.com/Heavybullets8/heavy_script.git"
        if ! update_repo "$script_dir"; then
            echo "Failed to convert to git repository"
            exit 1
        fi
    fi
else
    # Clone the script repository
    echo "Cloning $script_name repository..."
    cd "$HOME" || exit 1
    if ! git clone "https://github.com/Heavybullets8/heavy_script.git"; then
        echo "Failed to clone the repository"
        exit 1
    fi

    cd "$script_dir" || exit 1
    if ! update_repo "$script_dir"; then
        exit 1
    fi
fi


# Create the bin directory if it does not exist
if [[ ! -d "$bin_dir" ]]; then
    echo "Creating $bin_dir directory..."
    mkdir "$bin_dir"
fi

# Create symlink inside bin, to the script
echo "Creating $script_wrapper wrapper..."
ln -sf "$script_dir/bin/$script_name" "$script_wrapper"
chmod +x "$script_dir/bin/$script_name"


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


