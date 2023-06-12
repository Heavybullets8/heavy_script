#!/bin/bash


enable_apt() {
local apt_commands=("apt" "apt-get" "apt-key")
local success=true

for command_name in "${apt_commands[@]}"; do
    if [[ ! -x "$(command -v "${command_name}")" ]]; then
        echo "${command_name} is not executable. Changing permissions..."
        if chmod +x "$(command -v "${command_name}")"; then
            echo -e "${green}${command_name} is now executable.${reset}"
        else
            echo -e "${red}Failed to make ${command_name} executable.${reset}"
            success=false
        fi
    else
        echo -e "${green}${command_name} is already executable.${reset}"
    fi
done

if [ "$success" = true ]; then
    echo -e "\n${bold}Example usage:${reset}"
    echo -e "For most use cases, use ${blue}apt${reset}:"
    echo -e "  ${blue}apt update${reset}"
    echo -e "  ${blue}apt install package_name${reset}"
    
    echo -e "\nFor advanced users or specific cases, you can use ${blue}apt-get${reset}:"
    echo -e "  ${blue}apt-get update${reset}"
    echo -e "  ${blue}apt-get install package_name${reset}"
fi
}


