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
    local script_location="$script_path/bin/heavyscript"

    if ! grep -q "$script_location" "/root/$rc_file"; then
        echo -e "${blue}Adding $script_location to /root/$rc_file...${reset}"
        echo "export PATH=$script_location:\$PATH" >> "/root/$rc_file"
    fi
}


