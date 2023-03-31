#!/bin/bash


prune_help(){
    echo -e "${bold}Prune${reset}"
    echo -e "${bold}-----${reset}"
    echo -e "${blue}heavyscript prune${reset} | ${blue}[Option]${reset}"
    echo
    echo -e "${bold}Description${reset}"
    echo -e "${bold}-----------${reset}"
    echo -e "Prune all unused images"
    echo
    echo -e "${bold}Options${reset}"
    echo -e "${bold}-------${reset}"
    echo -e "${blue}--help${reset} | ${blue}-h${reset}"
    echo -e "    Display this help message."
    echo
}