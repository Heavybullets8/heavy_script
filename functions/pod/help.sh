#!/bin/bash


pod_help() {
    echo -e "${bold}Pod Handler${reset}"
    echo -e "${bold}-----------${reset}"
    echo -e "${blue}heavyscript pod${reset} | [-l | --logs | -s | --shell | -h | --help]"
    echo
    echo -e "${bold}Description${reset}"
    echo -e "${bold}-----------${reset}"
    echo -e "Manage pod-related actions such as checking logs or opening a shell"
    echo
    echo -e "${bold}Options${reset}"
    echo -e "${bold}-------${reset}"
    echo -e "${blue}-l${reset}, ${blue}--logs${reset}"
    echo -e "    Display container logs."
    echo -e "${blue}-s${reset}, ${blue}--shell${reset}"
    echo -e "    Open a shell for the container."
    echo -e "${blue}-h${reset}, ${blue}--help${reset}"
    echo -e "    Display this help message."
    echo
}

