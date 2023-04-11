#!/bin/bash


self_update_help() {
    echo -e "${bold}Self-Update${reset}"
    echo -e "${bold}-----------${reset}"
    echo -e "${blue}heavyscript self-update${reset} | [-h | --help]"
    echo
    echo -e "${bold}Description${reset}"
    echo -e "${bold}-----------${reset}"
    echo -e "Preform a self-update of the heavyscript script."
    echo
    echo -e "${bold}Options${reset}"
    echo -e "${bold}-------${reset}"
    echo -e "${blue}--major${reset}"
    echo -e "    Update to the next major version of heavyscript if available."
    echo -e "${blue}-h${reset} | ${blue}--help${reset}"
    echo -e "    Display this help message."
    echo
}
