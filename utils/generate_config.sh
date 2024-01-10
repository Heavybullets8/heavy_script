#!/bin/bash


generate_config_ini() {
    if [ ! -f config.ini ]; then
        cp .default.config.ini config.ini
        echo -e "${green}config.ini file generated${reset}"
        echo -e "You can modify default values in the config.ini file if needed"
        sleep 5
    fi
}

add_database_options() {
    local config_file="config.ini"

    # Check if the stop_before_dump option exists
    if ! grep -q "^stop_before_dump=" "$config_file"; then
        # Add the stop_before_dump option with a default value and description
        awk -i inplace -v stop_before_dump_option="\n# Apps listed here will have their deployments shut down prior to their CNPG Database dump\n# This is usually unnecessary, and unless otherwise recommended, leave blank\n# Example: stop_before_dump=nextcloud,appname,appname\nstop_before_dump=\"\"\n" '/^dump_folder=.*/ { print; print stop_before_dump_option; next }1' "$config_file"
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
