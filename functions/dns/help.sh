#!/bin/bash


dns_help() {
    echo -e "${bold}DNS Handler${reset}"
    echo -e "${bold}-----------${reset}"
    echo -e "${blue}heavyscript dns | ${blue}[Option]${reset}"
    echo
    echo -e "${bold}Description${reset}"
    echo -e "${bold}-----------${reset}"
    echo -e "List all ix DNS records"
    echo
    echo -e "${bold}Options${reset}"
    echo -e "${bold}-------${reset}"
    echo -e "${blue}-a${reset}, ${blue}--all${reset}"
    echo -e "    Display all DNS information."
    echo -e "${blue}--no-config${reset}"
    echo -e "    Ignore the settings in your config.ini file."
    echo -e "${blue}-h${reset}, ${blue}--help${reset}"
    echo -e "    Display this help message."
    echo
}


