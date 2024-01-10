#!/bin/bash


dns_help() {
    echo -e "${bold}DNS Handler${reset}"
    echo -e "${bold}-----------${reset}"
    echo -e "${blue}heavyscript dns | ${blue}[AppNames]${reset}"
    echo
    echo -e "${bold}Description${reset}"
    echo -e "${bold}-----------${reset}"
    echo -e "List all ix DNS records. Optionally, specify one or more app names to list DNS records for those specific apps."
    echo
    echo -e "${bold}Options${reset}"
    echo -e "${bold}-------${reset}"
    echo -e "${blue}AppName${reset}"
    echo -e "    Ignore the settings in your config.ini file."
    echo -e "${blue}-h${reset}, ${blue}--help${reset}"
    echo -e "    Display this help message."
    echo
    echo -e "${bold}Example${reset}"
    echo -e "${bold}-------${reset}"
    echo -e "    ${blue}heavyscript dns sonarr${reset}"
    echo -e "    ${blue}heavyscript dns radarr nextcloud${reset}"
    echo -e "    ${blue}heavyscript dns${reset} - Displays DNS records for all apps"
    echo
}



