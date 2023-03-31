#!/bin/bash


main_help(){
    clear -x
    echo -e "${bold}HeavyScript${reset}"
    echo -e "${bold}-----------${reset}"
    echo -e "${blue}heavyscript${reset} | ${blue}[Utility]${reset} | ${blue}[Option]${reset}"
    echo
    echo -e "${bold}HeavyScript Menu${reset}"
    echo -e "${bold}----------------${reset}"
    echo -e "${blue}heavyscript${reset}"
    echo
    echo -e "${bold}Utilities${reset}               | ${bold}[Options]${reset}"
    echo -e "${bold}---------${reset}               | ${bold}---------${reset}"
    echo -e "${blue}heavyscript app${reset}         | [${blue}--start${reset}|${blue}--stop${reset}|${blue}--restart${reset}|${blue}--delete${reset}|${blue}--help${reset}]"
    echo -e "${blue}heavyscript backup${reset}      | [${blue}--create${reset}|${blue}--restore${reset}|${blue}--delete${reset}|${blue}--help${reset}]"
    echo -e "${blue}heavyscript dns${reset}         | [${blue}--all${reset}|${blue}--help${reset}]"
    echo -e "${blue}heavyscript git${reset}         | [${blue}--branch${reset}|${blue}--global-path${reset}|${blue}--help${reset}]"
    echo -e "${blue}heavyscript pod${reset}         | [${blue}--logs${reset}|${blue}--shell${reset}|${blue}--help${reset}]"
    echo -e "${blue}heavyscript pvc${reset}         | [${blue}--mount${reset}|${blue}--unmount${reset}|${blue}--help${reset}]"
    echo -e "${blue}heavyscript self-update${reset} | [${blue}--major${reset}|${blue}--help${reset}]"
    echo -e "${blue}heavyscript update${reset}      | [${blue}--help${reset}]"
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

