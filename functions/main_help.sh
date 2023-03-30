#!/bin/bash


main_help(){
    clear -x

    echo -e "${bold}HeavyScript Menu${reset}"
    echo -e "${bold}----------------${reset}"
    echo -e "${blue}heavyscript${reset} [-h|--help]"
    echo
    echo -e "${bold}Utilities${reset}"
    echo -e "${bold}---------${reset}"
    echo -e "${blue}heavyscript app${reset}        | [--start|--stop|--restart|--delete|--help]"
    echo -e "${blue}heavyscript backup${reset}     | [--create|--restore|--delete|--help]"
    echo -e "${blue}heavyscript dns${reset}        | [--all|--help]"
    echo -e "${blue}heavyscript git${reset}        | [--branch|--global-path|--help]"
    echo -e "${blue}heavyscript pod${reset}        | [--logs|--shell|--help]"
    echo -e "${blue}heavyscript pvc${reset}        | [--mount|--unmount|--help]"
    echo -e "${blue}heavyscript self-update${reset}| [--major|--help]"
    echo -e "${blue}heavyscript update${reset}     | [--help]"
    echo
    echo -e "${bold}Configuration${reset}"
    echo -e "${bold}-------------${reset}"
    echo -e "The config.ini file sets default values for various functions of the script."
    echo -e "To ignore the modified config and use default values, add the ${blue}--no-config${reset} option."
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

