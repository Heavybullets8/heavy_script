#!/bin/bash


help(){
    clear -x

    echo -e "${bold}HeavyScript Menu${reset}"
    echo -e "${bold}----------------${reset}"
    echo -e "${blue}heavyscript${reset}"
    echo
    echo -e "${bold}Utilities${reset}"
    echo -e "${bold}---------${reset}"
    echo -e "${blue}--mount${reset}         | Access the mounting feature to mount or unmount PVC data"
    echo -e "${blue}--restore${reset}       | Open a menu to restore a backup from the \"ix-applications\" dataset"
    echo -e "${blue}--delete-backup${reset} | Open a menu to delete backups from your system"
    echo -e "${blue}--dns${reset}           | View all application DNS names and web ports (-v for verbose output)"
    echo -e "${blue}--cmd${reset}           | Open a shell for a selected application"
    echo -e "${blue}--logs${reset}          | View log file for a selected application"
    echo -e "${blue}--start-app${reset}     | Opens menu to start an application"
    echo -e "${blue}--stop-app${reset}      | Opens menu to stop an application"
    echo -e "${blue}--restart-app${reset}   | Opens menu to restart an application"
    echo -e "${blue}--delete-app${reset}    | Opens menu to delete an application"
    echo 
    echo -e "${bold}Update Specific Options${reset}"
    echo -e "${bold}-----------------------${reset}"
    echo -e "${blue}-U${reset}     | Update all applications, disregarding version numbers"
    echo -e "${blue}-U 5${reset}   | Same as above, but in batches of 5 applications"
    echo -e "${blue}-u${reset}     | Update all applications, excluding major release updates"
    echo -e "${blue}-u 5${reset}   | Same as above, but in batches of 5 applications"
    echo -e "${blue}-r${reset}     | Revert applications if their update fails"
    echo -e "${blue}-i${reset}     | Exclude an application from updates, see example below."
    echo -e "${blue}-S${reset}     | Stop applications prior to updating"
    echo -e "${blue}-t 500${reset} | Wait time for an application to become ACTIVE, default is 500 seconds"
    echo -e "${blue}--ignore-img${reset} | Skip container image updates"
    echo
    echo -e "${bold}General Options${reset}"
    echo -e "${bold}---------------${reset}"
    echo -e "${gray}These options can be used in conjunction with the update options above${reset}"
    echo -e "${gray}Alternatively, use these options individually or combined with other commands${reset}"
    echo -e "${blue}-b 14${reset} | Backup your ix-applications dataset prior to updating, up to the number specified"
    echo -e "${blue}-s${reset}    | Synchronize catalog information"
    echo -e "${blue}-p${reset}    | Remove unused or old Docker images"
    echo -e "${blue}--self-update${reset} | Update HeavyScript prior to executing other commands"
    echo 
    echo -e "${bold}Miscellaneous${reset}"
    echo -e "${bold}-------------${reset}"
    echo -e "${blue}-h${reset} | Display this help menu"
    echo -e "${blue}-v${reset} | Display detailed output"
    echo
    echo -e "${bold}Examples${reset}"
    echo -e "${bold}--------${reset}"
    echo -e "${blue}heavyscript -b 14 -i nextcloud -i sonarr -t 600 -vrsUp --self-update${reset}"
    echo -e "${blue}heavyscript -b 10 -i nextcloud -i sonarr -vrsp -u 10 --self-update${reset}"
    echo -e "${blue}heavyscript --mount${reset}"
    echo -e "${blue}heavyscript --dns${reset}"
    echo -e "${blue}heavyscript --restore${reset}"
    echo
    echo -e "${bold}Cron Job${reset}"
    echo -e "${bold}--------${reset}"
    echo -e "${blue}bash /root/heavy_script/heavy_script.sh -b 14 -rsp --self-update -u 10${reset}"
    echo
    exit
}