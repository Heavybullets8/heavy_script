#!/bin/bash


pod_help() {
    echo -e "${bold}Pod Handler${reset}"
    echo -e "${bold}-----------${reset}"
    echo -e "${blue}heavyscript pod [Option] [APPNAME]${reset}"
    echo
    echo -e "${bold}Description${reset}"
    echo -e "${bold}-----------${reset}"
    echo -e "Manage pod-related actions such as checking logs or opening a shell. Specify an APPNAME to directly interact or omit for a menu-driven experience."
    echo
    echo -e "${bold}Options${reset}"
    echo -e "${bold}-------${reset}"
    echo -e "${blue}-l${reset}, ${blue}--logs${reset} [APPNAME]"
    echo -e "    Display container logs. If no APPNAME is provided, the user will be prompted to select one from the menu."
    echo -e "${blue}-s${reset}, ${blue}--shell${reset} [APPNAME]"
    echo -e "    Open a shell for the container. If no APPNAME is provided, the user will be prompted to select one from the menu."
    echo -e "${blue}-h${reset}, ${blue}--help${reset}"
    echo -e "    Display this help message."
    echo
}
