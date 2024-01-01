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

USER_HOME=$(get_user_home)

velero_symlink() {
    local context="$1"  # Context of the symlink creation (install, update, or check)

    ln -sf "$USER_HOME/bin/velero" /usr/local/bin/velero
    case "$context" in
        "install")
            echo -e "${green}Symlink created in ${blue}/usr/local/bin${green} for the first time.${reset}"
            ;;
        "update")
            echo -e "${green}Symlink in ${blue}/usr/local/bin${green} updated.${reset}"
            ;;
        "check")
            echo -e "${yellow}Symlink in ${blue}/usr/local/bin${yellow} verified and recreated if necessary.${reset}"
            ;;
    esac
}

velero_set_conf() {
    local namespace

    if "$USER_HOME"/bin/velero client config set kubeconfig=/etc/rancher/k3s/k3s.yaml; then
        echo -e "${green}Velero kubeconfig set successfully.${reset}"
    else
        echo -e "${red}Failed to set Velero kubeconfig.${reset}"
    fi

    echo -e "\nSetting Velero namespace..."
    namespace="ix-$(velero_app_find)"
    if [[ "$namespace" != "ix-NULL" ]]; then
        if "$USER_HOME"/bin/velero client config set namespace="$namespace"; then
            echo -e "${green}Velero namespace set successfully.${reset}"
        else
            echo -e "${red}Failed to set Velero namespace.${reset}"
        fi
    else
        echo -e "${red}Failed to set ${blue}Velero${red} namespace.${reset}"
        echo -e "${red}Please ensure that ${blue}Velero${red} is installed from the ${blue}Truecharts${red}, ${blue}enterprise${red} train.${reset}"
        echo -e "${red}After installing the application, please run this function again.${reset}"
    fi
}

velero_app_find() {
    # Read all application names into an array
    mapfile -t all_apps < <(cli -m csv -c 'app chart_release query name' | tail -n +2 | tr -d " \t\r" | awk 'NF')

    # Create arrays for apps starting with 'V' and the rest
    declare -a v_apps
    declare -a other_apps

    for app in "${all_apps[@]}"; do
        if [[ $app == v* ]]; then
            v_apps+=("$app")
        else
            other_apps+=("$app")
        fi
    done

    # Combine the arrays, with 'V' apps first
    combined_apps=("${v_apps[@]}" "${other_apps[@]}")

    # Loop through each app name
    for app_name in "${combined_apps[@]}"; do
        # Get chart metadata name
        chart_metadata_name=$(midclt call chart.release.get_instance "$app_name" | jq -r .chart_metadata.name)

        # Check if the chart metadata name is 'velero'
        if [[ "$chart_metadata_name" == "velero" ]]; then
            echo "$app_name"
            return 0
        fi
    done

    echo "NULL"
    return 1
}

# Function to get the latest Velero release URL
velero_latest_release_url() {
    wget -qO- "https://api.github.com/repos/vmware-tanzu/velero/releases/latest" | jq -r '.assets[] | select(.name | contains("linux-amd64")).browser_download_url'
}

# Function to install Velero
velero_install() {
    local release_url
    release_url=$(velero_latest_release_url)
    wget -qO velero.tar.gz "$release_url"
    mkdir -p "$USER_HOME/bin/velero_real"
    tar -xzf velero.tar.gz -C "$USER_HOME/bin/velero_real"

    # Find and move the Velero binary to the velero_real directory
    local velero_dir
    velero_dir=$(find "$USER_HOME/bin/velero_real" -type d -name "velero-*" -print -quit)
    if [[ -d "$velero_dir" ]]; then
        mv "$velero_dir/velero" "$USER_HOME/bin/velero_real/velero"
        rm -rf "$velero_dir"
    fi

    # Create or update the wrapper script
    cat > "$USER_HOME/bin/velero" << EOF
#!/bin/bash
# Wrapper script for Velero
if [[ \$1 == "install" ]]; then
    echo "'velero install' is not allowed. Please use the application instead..."
else
    "$USER_HOME/bin/velero_real/velero" "\$@"
fi
EOF
    chmod +x "$USER_HOME/bin/velero_real/velero"
    chmod +x "$USER_HOME/bin/velero"
    rm velero.tar.gz
    ln -sf "$USER_HOME/bin/velero" /usr/local/bin/velero
    echo -e "${green}Velero installed successfully.${reset}"
}

# Function to check Velero installation and decide action
velero_check() {
    if command -v velero &> /dev/null; then
        local current_version
        local latest_version
        latest_version=$(wget -qO- "https://api.github.com/repos/vmware-tanzu/velero/releases/latest" | jq -r '.tag_name')
        current_version=$(velero version --client-only | grep Version | cut -d ':' -f 2 | xargs)

        if [ "$current_version" != "$latest_version" ]; then
            echo -e "${green}Updating Velero to the latest version.${reset}"
            velero_install
            # Recreate the symlink after updating
            velero_symlink "update"
        else
            echo -e "${green}Velero is up to date.${reset}"
            # Check and recreate the symlink if needed
            velero_symlink "check"
        fi
    else
        echo -e "${yellow}Velero is not installed. Installing now.${reset}"
        velero_install
        # Create the symlink for the first time
        velero_symlink "install"
    fi
    velero_set_conf
}