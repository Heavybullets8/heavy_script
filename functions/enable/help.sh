#!/bin/bash


enable_help() {
    echo -e "${bold}Enable/Disable Handler${reset}"
    echo -e "${bold}---------------------${reset}"
    echo -e "${blue}heavyscript enable | ${blue}[FEATURE]${reset}"
    echo -e "${blue}heavyscript enable | ${blue}--disable-[FEATURE]${reset}"
    echo
    echo -e "${bold}Description${reset}"
    echo -e "${bold}-----------${reset}"
    echo -e "    Enable or disable specific locked-down functions in TrueNAS SCALE."
    echo
    echo -e "${bold}FEATURES${reset}"
    echo -e "${bold}-------${reset}"
    echo -e "${blue}--api${reset}"
    echo -e "    Enables external access to the Kubernetes API server"
    echo -e "${blue}--disable-api${reset}"
    echo -e "    Disables external access to the Kubernetes API server"
    echo -e "${blue}--apt${reset}"
    echo -e "    Enable apt, apt-get, apt-key and dpkg."
    echo -e "${blue}--disable-apt${reset}"  
    echo -e "    Disable apt, apt-get, apt-key, and dpkg."  
    echo -e "${blue}--helm${reset}"
    echo -e "    Enable helm commands."
    echo -e "${blue}--disable-helm${reset}"
    echo -e "    Disable helm commands."
    echo -e "${blue}-h, --help${reset}"
    echo -e "    Show this help message and exit."
    echo
    echo -e "${bold}Example${reset}"
    echo -e "${bold}-------${reset}"
    echo -e "    ${blue}heavyscript enable --api${reset}"
    echo -e "    ${blue}heavyscript enable --apt${reset}"
    echo -e "    ${blue}heavyscript enable --disable-apt${reset}"
    echo
}