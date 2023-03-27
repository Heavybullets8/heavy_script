#!/bin/bash


main_help(){
    clear -x

    echo -e "${bold}HeavyScript Menu${reset}"
    echo -e "${bold}----------------${reset}"
    echo -e "${blue}heavyscript${reset}"
    echo
    echo -e "${bold}Utilities${reset}"
    echo -e "${bold}---------${reset}"
    echo -e "${blue}heavyscript app${reset}       | [--start|--stop|--restart|--delete|--help]"
    echo -e "${blue}heavyscript backup${reset}    | [--create|--restore|--delete|--help]"
    echo -e "${blue}heavyscript dns${reset}       | [--all|--help]"
    echo -e "${blue}heavyscript git${reset}       | [--branch|--global-path|--help]"
    echo -e "${blue}heavyscript pod${reset}       | [--logs|--shell|--help]"
    echo -e "${blue}heavyscript pvc${reset}       | [--mount|--unmount|--help]"
    echo -e "${blue}heavyscript update${reset}    | [--help]"
    echo
}