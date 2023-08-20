#!/bin/bash

pvc_help() {
    echo -e "${bold}PVC Handler${reset}"
    echo -e "${bold}-----------${reset}"
    echo -e "${blue}heavyscript pvc [Option] [APPNAME]${reset}"
    echo
    echo -e "${bold}Description${reset}"
    echo -e "${bold}-----------${reset}"
    echo -e "Manage PVC-related actions such as mounting or unmounting PVCs. Specify an APPNAME to directly mount its PVCs or omit for a menu-driven experience."
    echo
    echo -e "${bold}Options${reset}"
    echo -e "${bold}-------${reset}"
    echo -e "${blue}-m${reset}, ${blue}--mount${reset} [APPNAME]"
    echo -e "    Mount PVCs for a given app. If no APPNAME is provided, the user will be prompted to select one from the menu."
    echo -e "${blue}-u${reset}, ${blue}--unmount${reset} [APPNAME]"
    echo -e "    Unmount PVCs for a specific app. If no APPNAME is provided, the user will be prompted to select one from the menu."
    echo -e "    Unmount all PVCs with ${blue}heavyscript pvc --unmount ALL${reset}"    
    echo -e "${blue}-h${reset}, ${blue}--help${reset}"
    echo -e "    Display this help message."
    echo
}
