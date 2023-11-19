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
    mkdir -p "$HOME/bin/velero_real"
    tar -xzf velero.tar.gz -C "$HOME/bin/velero_real"

    # Find and move the Velero binary to the velero_real directory
    local velero_dir
    velero_dir=$(find "$HOME/bin/velero_real" -type d -name "velero-*" -print -quit)
    if [[ -d "$velero_dir" ]]; then
        mv "$velero_dir/velero" "$HOME/bin/velero_real/velero"
        rm -rf "$velero_dir"
    fi

    # Create or update the wrapper script
    cat > "$HOME/bin/velero" << EOF
#!/bin/bash
# Wrapper script for Velero
if [[ \$1 == "install" ]]; then
    echo "Direct 'velero install' is not allowed. Please use the containerized version."
else
    "$HOME/bin/velero_real/velero" "\$@"
fi
EOF
    chmod +x "$HOME/bin/velero_real/velero"
    chmod +x "$HOME/bin/velero"
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