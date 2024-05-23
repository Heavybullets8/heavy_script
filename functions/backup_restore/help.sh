#!/bin/bash

backup_help() {
    echo -e "${bold}Backup Handler${reset}"
    echo -e "${bold}--------------${reset}"
    echo -e "${blue}heavyscript backup [Option]${reset}"
    echo
    echo -e "${bold}Description${reset}"
    echo -e "${bold}-----------${reset}"
    echo -e "Create, restore, delete, list, and import backups."
    echo
    echo -e "${bold}Options${reset}"
    echo -e "${bold}-------${reset}"
    echo -e "${blue}-c${reset}, ${blue}--create${reset} <retention>"
    echo -e "    Create a backup with the specified retention number."
    echo -e "${blue}-A${reset}, ${blue}--restore-all${reset} [backup_name]"
    echo -e "    Restore all backups. If a backup name is provided, restore that backup."
    echo -e "    Otherwise open an interactive menu to select a backup."
    echo -e "${blue}-S${reset}, ${blue}--restore-single${reset} [backup_name]"
    echo -e "    Restore a single backup. If a backup name is provided, restore that backup."
    echo -e "    Otherwise open an interactive menu to select a backup."
    echo -e "${blue}-d${reset}, ${blue}--delete${reset} [backup_name]"
    echo -e "    Delete a backup. If a backup name is provided, delete that specific backup."
    echo -e "    Otherwise open an interactive menu to select a backup."
    echo -e "${blue}-l${reset}, ${blue}--list${reset}"
    echo -e "    List all backups."
    echo -e "${blue}-i${reset}, ${blue}--import${reset} [backup_name] [app_name]"
    echo -e "    Import a specific backup for an application. If no backup name or app name is provided, the user will be prompted to select one."
    echo -e "${blue}-h${reset}, ${blue}--help${reset}"
    echo -e "    Display this help message."
    echo
}