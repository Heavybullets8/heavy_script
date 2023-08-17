#!/bin/bash


toggle_apt() {
    local action="$1"  # either "enable" or "disable"
    local apt_commands=("apt" "apt-get" "apt-key" "dpkg")
    local success=true

    for command_name in "${apt_commands[@]}"; do
        if [[ "$action" == "enable" ]]; then
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
        elif [[ "$action" == "disable" ]]; then
            if [[ -x "$(command -v "${command_name}")" ]]; then
                echo "${command_name} is executable. Removing permissions..."
                if chmod -x "$(command -v "${command_name}")"; then
                    echo -e "${green}${command_name} is no longer executable.${reset}"
                else
                    echo -e "${red}Failed to make ${command_name} non-executable.${reset}"
                    success=false
                fi
            else
                echo -e "${green}${command_name} is already non-executable.${reset}"
            fi
        fi
    done

    if [ "$success" = true ] && [ "$action" = "enable" ]; then
        echo -e "\n${bold}Example usage:${reset}"
        echo -e "For most use cases, use ${blue}apt${reset}:"
        echo -e "  ${blue}apt update${reset}"
        echo -e "  ${blue}apt install package_name${reset}"
        
        echo -e "\nFor advanced users or specific cases, you can use ${blue}apt-get${reset}:"
        echo -e "  ${blue}apt-get update${reset}"
        echo -e "  ${blue}apt-get install package_name${reset}"
    fi
}


