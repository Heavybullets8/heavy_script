#!/bin/bash

# Function to get the latest Velero release URL
velero_latest_release_url() {
    wget -qO- "https://api.github.com/repos/vmware-tanzu/velero/releases/latest" | jq -r '.assets[] | select(.name | contains("linux-amd64")).browser_download_url'
}

# Function to install Velero
velero_install() {
    local release_url
    release_url=$(velero_latest_release_url)
    wget -qO velero.tar.gz "$release_url"
    mkdir -p "$HOME/bin"
    tar -xzf velero.tar.gz -C "$HOME/bin"

    # Move velero from its extracted folder to $HOME/bin and set executable permissions
    local velero_dir
    velero_dir=$(find "$HOME/bin" -type d -name "velero-*" -print -quit)
    if [[ -d "$velero_dir" && "$velero_dir" == "$HOME/bin/velero-"* ]]; then
        mv "$velero_dir/velero" "$HOME/bin/velero"
        chmod +x "$HOME/bin/velero"
        # Safely remove the extracted directory
        find "$HOME/bin" -type d -name "velero-*" -exec rm -r {} +
    fi

    ln -sf "$HOME/bin/velero" /usr/local/bin/velero
    rm velero.tar.gz
    echo "Velero installed successfully."
}

# Function to update Velero
velero_update() {
    if command -v velero &> /dev/null; then
        velero_install
        echo "Velero updated successfully."
    else
        echo "Velero is not installed. Installing now."
        velero_install
    fi
}

# Function to check Velero installation and decide action
velero_check() {
    if command -v velero &> /dev/null; then
        local current_version
        local latest_version
        latest_version=$(wget -qO- "https://api.github.com/repos/vmware-tanzu/velero/releases/latest" | jq -r '.tag_name')
        current_version=$(velero version --client-only | grep Version | cut -d ':' -f 2 | xargs)

        if [ "$current_version" != "$latest_version" ]; then
            echo "Updating Velero to the latest version."
            velero_update
        else
            echo "Velero is up to date."
        fi
    else
        echo "Velero is not installed. Installing now."
        velero_install
    fi
}