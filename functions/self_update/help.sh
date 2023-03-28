#!/bin/bash


self_update_help() {
    echo -e "${bold}Self-Update${reset}"
    echo -e "${bold}-----------${reset}"
    echo -e "${blue}heavyscript self-update${reset} | [-U | --self-update | self-update | -h | --help]"
    echo
    echo -e "${bold}Description${reset}"
    echo -e "${bold}-----------${reset}"
    echo -e "Change the current branch or place HeavyScript in the global path"
    echo
    echo -e "${bold}Options${reset}"
    echo -e "${bold}-------${reset}"
    echo -e "${blue}-b${reset}, ${blue}--branch${reset}"
    echo -e "    Choose a branch to work with."
    echo -e "${blue}-g${reset}, ${blue}--global${reset}"
    echo -e "    Add the script to the global path."
    echo -e "${blue}-h${reset}, ${blue}--help${reset}"
    echo -e "    Display this help message."
    echo
}
