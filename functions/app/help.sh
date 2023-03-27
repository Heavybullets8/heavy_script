#!/bin/bash


app_help() {
    echo -e "${bold}App Handler${reset}"
    echo -e "${bold}-----------${reset}"
    echo -e "${blue}heavyscript app${reset} | [-s | --start | -x | --stop | -r | --restart | -d | --delete | -h | --help]"
    echo
    echo -e "${bold}Description${reset}"
    echo -e "${bold}-----------${reset}"
    echo -e "Start, stop, restart and delete applications"
    echo
    echo -e "${bold}Options${reset}"
    echo -e "${bold}-------${reset}"
    echo -e "${blue}-s${reset}, ${blue}--start${reset}"
    echo -e "    Start an application."
    echo -e "${blue}-x${reset}, ${blue}--stop${reset}"
    echo -e "    Stop an application."
    echo -e "${blue}-r${reset}, ${blue}--restart${reset}"
    echo -e "    Restart an application."
    echo -e "${blue}-d${reset}, ${blue}--delete${reset}"
    echo -e "    Delete an application."
    echo -e "${blue}-h${reset}, ${blue}--help${reset}"
    echo -e "    Display this help message."
    echo
}

