#!/bin/bash


backup_help() {
    echo -e "${bold}Backup Handler${reset}"
    echo -e "${bold}--------------${reset}"
    echo -e "${blue}heavyscript backup${reset} | [-c | --create | -r | --restore | -d | --delete | -h | --help]"
    echo
    echo -e "${bold}Description${reset}"
    echo -e "${bold}-----------${reset}"
    echo -e "Manage ix-applications backups"
    echo
    echo -e "${bold}Options${reset}"
    echo -e "${bold}-------${reset}"
    echo -e "${blue}-c${reset}, ${blue}--create${reset} followed by a number"
    echo -e "    Create a backup."
    echo -e "${blue}-r${reset}, ${blue}--restore${reset}"
    echo -e "    Restore a backup."
    echo -e "${blue}-d${reset}, ${blue}--delete${reset}"
    echo -e "    Delete a backup."
    echo -e "${blue}-h${reset}, ${blue}--help${reset}"
    echo -e "    Display this help message."
    echo
    echo -e "${bold}Examples${reset}"
    echo -e "${bold}--------${reset}"
    echo -e "${blue}heavyscript backup -c 15${reset}"
}
