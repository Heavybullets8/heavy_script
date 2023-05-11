#!/bin/bash


pvc_help() {
    echo -e "${bold}PVC Handler${reset}"
    echo -e "${bold}-----------${reset}"
    echo -e "${blue}heavyscript pvc${reset} | [Option]"
    echo
    echo -e "${bold}Description${reset}"
    echo -e "${bold}-----------${reset}"
    echo -e "Manage PVC-related actions with the PVC handler"
    echo
    echo -e "${bold}Options${reset}"
    echo -e "${bold}-------${reset}"
    echo -e "${blue}-m${reset}, ${blue}--mount${reset}"
    echo -e "    Open a menu to mount PVCs."
    echo -e "${blue}-u${reset}, ${blue}--unmount${reset}"
    echo -e "    Unmount all mounted PVCs."
    echo -e "${blue}-h${reset}, ${blue}--help${reset}"
    echo -e "    Display this help message."
    echo
}
