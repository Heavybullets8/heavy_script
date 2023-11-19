#!/bin/bash


main_help(){
    clear -x
    echo -e "${bold}HeavyScript${reset}"
    echo -e "${bold}-----------${reset}"
    echo -e "${blue}heavyscript${reset} | ${blue}[Function]${reset} | ${blue}[Flag]${reset}"
    echo
    echo -e "${bold}HeavyScript Menu${reset}"
    echo -e "${bold}----------------${reset}"
    echo -e "${blue}heavyscript${reset}"
    echo
    echo -e "${bold}Functions${reset}"
    echo -e "${bold}---------${reset}"
    echo -e "${blue}heavyscript app${reset}         | Manage applications (start, stop, restart, delete)"
    echo -e "${blue}heavyscript backup${reset}      | Manage backups (create, restore, delete)"
    echo -e "${blue}heavyscript dns${reset}         | View application DNS names"
    echo -e "${blue}heavyscript git${reset}         | Manage Git repositories (switch branch, set global path)"
    echo -e "${blue}heavyscript pod${reset}         | Access pod logs and shells"
    echo -e "${blue}heavyscript pvc${reset}         | Manage PVCs (mount, unmount)"
    echo -e "${blue}heavyscript self-update${reset} | Update HeavyScript (with or without major version update)"
    echo -e "${blue}heavyscript sync${reset}        | Syncs the catalog"
    echo -e "${blue}heavyscript update${reset}      | Update applications"
    echo -e "${blue}heavyscript enable${reset}      | Enable specific features (e.g., k3s remote node, apt)"
    echo
    echo -e "${bold}Configuration${reset}"
    echo -e "${bold}-------------${reset}"
    echo -e "The config.ini file sets default values for various functions of the script."
    echo -e "To ignore the modified config and use default values, add the ${blue}--no-config${reset} flag."
    echo
    echo -e "${bold}Examples${reset}"
    echo -e "${bold}--------${reset}"
    echo -e "${blue}heavyscript app --start${reset}"
    echo -e "${blue}heavyscript backup --create 14${reset}"
    echo -e "${blue}heavyscript dns --no-config${reset}"
    echo -e "${blue}heavyscript git --branch${reset}"
    echo -e "${blue}heavyscript pod --logs${reset}"
    echo -e "${blue}heavyscript pvc --mount${reset}"
    echo -e "${blue}heavyscript update${reset}"
}
