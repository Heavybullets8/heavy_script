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

ensure_symlink() {
    local current_version=$(cli -c "system version_short" | sed -r 's/\.//g')
    if [ $current_version -ge 24040 ]; then
        echo "Ignoring symlink check for version 24.04 and newer."
        return
    fi

    local system_script_wrapper="/usr/local/bin/heavyscript"
    local script_location="$script_path/bin/heavyscript"

    if [[ ! -L "$system_script_wrapper" || ! -e "$system_script_wrapper" ]]; then
        echo "Warning: Symlink from $script_location to $system_script_wrapper is broken."

        if [[ $EUID -eq 0 ]]; then
            echo -e "Restoring symlink in $system_script_wrapper...\n"
            ln -sf "$script_location" "$system_script_wrapper"
            chmod +x "$script_location"
        else
            echo "Warning: The script is not running as root. To restore the symlink, run the script with sudo using the following command:"
            echo "sudo bash $script"
            echo "or run the script as the root user."
            sleep 5
        fi
    fi
}