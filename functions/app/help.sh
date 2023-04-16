#!/bin/bash


app_help() {
    echo -e "${bold}App Handler${reset}"
    echo -e "${bold}-----------${reset}"
    echo -e "${blue}heavyscript app [Option] [app_name]${reset}"
    echo
    echo -e "${bold}Description${reset}"
    echo -e "${bold}-----------${reset}"
    echo -e "Start, stop, restart and delete applications"
    echo
    echo -e "${bold}Options${reset}"
    echo -e "${bold}-------${reset}"
    echo -e "${blue}-s${reset}, ${blue}--start${reset} [app_name]"
    echo -e "    Start an application. If no app_name is provided, the user will be prompted to select one."
    echo -e "${blue}-x${reset}, ${blue}--stop${reset} [app_name]"
    echo -e "    Stop an application. If no app_name is provided, the user will be prompted to select one."
    echo -e "${blue}-r${reset}, ${blue}--restart${reset} [app_name]"
    echo -e "    Restart an application. If no app_name is provided, the user will be prompted to select one."
    echo -e "${blue}-d${reset}, ${blue}--delete${reset} [app_name]"
    echo -e "    Delete an application. If no app_name is provided, the user will be prompted to select one."
    echo -e "${blue}-h${reset}, ${blue}--help${reset}"
    echo -e "    Display this help message."
    echo
}


