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
    config_file="config.ini"

    # Check if the [databases] section exists
    if ! grep -q "^\[databases\]" "$config_file"; then
        # Add the [databases] section to the config file
        echo -e "\n[databases]" >> "$config_file"
    fi

    # Check if the dump_folder option exists
    if ! grep -q "^dump_folder=" "$config_file"; then
        # Add the dump_folder option with a default value and description
        sed -i '/^\[databases\]/a # File path for database dump folder\n\
dump_folder=database_dumps' "$config_file"
    fi
}