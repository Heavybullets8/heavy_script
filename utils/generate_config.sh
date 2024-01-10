#!/bin/bash


generate_config_ini() {
    if [ ! -f config.ini ]; then
        cp .default.config.ini config.ini
        echo -e "${green}config.ini file generated${reset}"
        echo -e "You can modify default values in the config.ini file if needed"
        sleep 5
    fi
}

remove_dns_section() {
    local config_file="config.ini"

    # Check if the [DNS] section exists in the config.ini file
    if grep -q "^\[DNS\]" "$config_file"; then
        # Remove the [DNS] section from the config.ini file
        awk '/^\[DNS\]/ {flag=1; next} /^\[SELFUPDATE\]/ {flag=0} !flag' "$config_file" > temp.ini && mv temp.ini "$config_file"
    fi
}
