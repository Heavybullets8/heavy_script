#!/bin/bash


sync(){
    echo_sync+=("🅂 🅈 🄽 🄲") 
    cli -c 'app catalog sync_all' &> /dev/null && echo_sync+=("Catalog sync complete")

    #Dump the echo_array, ensures all output is in a neat order. 
    for i in "${echo_sync[@]}"
    do
        echo -e "$i"
    done
    echo
    echo
}
export -f sync


prune(){
    echo -e "🄿 🅁 🅄 🄽 🄴"  
    version="$(cli -c 'system version' | 
               awk -F '-' '{print $3}' | 
               awk -F '.' '{print $1 $2}' |  
               tr -d " \t\r\.")"
    if (( "$version" >= 2212 )); then
        if ! cli -c 'app container config prune prune_options={"remove_unused_images": true, "remove_stopped_containers": true}' | head -n -4; then
            echo -e "Failed to Prune Docker Images"
        fi
    else
        if ! docker image prune -af | grep "^Total"; then
            echo -e "Failed to Prune Docker Images"
        fi
    fi
}
export -f prune


title(){
    # Set the text color to frost
    txt_frost='\033[38;2;248;248;242m'

    # Set the text color to snowstorm
    txt_snowstorm='\033[38;2;109;113;120m'

    # Set the text color to glacier
    txt_glacier='\033[38;2;60;78;82m'

    # Set the text color to frostflower
    txt_frostflower='\033[38;2;215;216;216m'

    # Reset the text color
    txt_reset='\033[0m'

    echo -e "${txt_frost} _   _                        _____           _       _   ${txt_reset}"
    echo -e "${txt_snowstorm}| | | |                      /  ___|         (_)     | | ${txt_reset}"
    echo -e "${txt_glacier}| |_| | ___  __ ___   ___   _\\ \`--.  ___ _ __ _ _ __ | |_${txt_reset}"
    echo -e "${txt_frostflower}|  _  |/ _ \/ _\` \\ \ / / | | |\`--. \/ __| '__| | '_ \\ __|${txt_reset}"
    echo -e "${txt_snowstorm}| | | |  __/ (_| |\\ V /| |_| /\\__/ / (__| |  | | |_) | |_ ${txt_reset}"
    echo -e "${txt_glacier}\\_| |_/\\___|\\__,_| \\_/  \\__, \\____/ \\___|_|  |_| .__/ \\__|${txt_reset}"
    echo -e "${txt_frostflower}                         __/ |                 | |        ${txt_reset}"
    echo -e "${txt_snowstorm}                        |___/                  |_|        ${txt_reset}"
    echo -e "${txt_snowstorm}$hs_version${txt_reset}"
    echo
}
export -f title


help(){
    clear -x

    echo -e "${bold}Access the HeavyScript Menu${reset}"
    echo -e "${bold}---------------------------${reset}"
    echo -e "${blue}heavyscript${reset}"
    echo
    echo -e "${bold}Utilities${reset}"
    echo -e "${bold}---------${reset}"
    echo -e "${blue}--mount${reset}         | Access the mounting feature to mount or unmount PVC data"
    echo -e "${blue}--restore${reset}       | Open a menu to restore a backup from the \"ix-applications\" dataset"
    echo -e "${blue}--delete-backup${reset} | Open a menu to delete backups from your system"
    echo -e "${blue}--dns${reset}           | View all application DNS names and web ports"
    echo -e "${blue}--cmd${reset}           | Open a shell for a selected application"
    echo -e "${blue}--logs${reset}          | View log file for a selected application"
    echo 
    echo -e "${bold}Update Specific Options${reset}"
    echo -e "${bold}-----------------------${reset}"
    echo -e "${blue}-U${reset}     | Update all applications, disregarding version numbers"
    echo -e "${blue}-U 5${reset}   | Same as above, but in batches of 5 applications"
    echo -e "${blue}-u${reset}     | Update all applications, excluding major release updates"
    echo -e "${blue}-u 5${reset}   | Same as above, but in batches of 5 applications"
    echo -e "${blue}-r${reset}     | Revert applications if their update fails"
    echo -e "${blue}-i${reset}     | Exclude an application from updates, see example below."
    echo -e "${blue}-S${reset}     | Stop applications before updating"
    echo -e "${blue}-t 500${reset} | Wait time for an application to become ACTIVE, default is 500 seconds"
    echo -e "${blue}--ignore-img${reset} | Skip container image updates"
    echo
    echo -e "${bold}General Options${reset}"
    echo -e "${bold}---------------${reset}"
    echo -e "${gray}These options can be used in conjunction with the update options above${reset}"
    echo -e "${gray}Alternatively, use these options individually or combined with other commands${reset}"
    echo -e "${blue}-b 14${reset} | Backup your ix-applications dataset before updating, up to the number specified"
    echo -e "${blue}-s${reset}    | Synchronize catalog information"
    echo -e "${blue}-p${reset}    | Remove unused or old Docker images"
    echo -e "${blue}--self-update${reset} | Update HeavyScript before executing other commands"
    echo
    echo -e "${bold}Miscellaneous${reset}"
    echo -e "${bold}-------------${reset}"
    echo -e "${blue}-h${reset} | Display this help menu"
    echo -e "${blue}-v${reset} | Display detailed output"
    echo
    echo -e "${bold}Examples${reset}"
    echo -e "${bold}--------${reset}"
    echo -e "${blue}heavyscript -b 14 -i portainer -i arch -i sonarr -t 600 -vrsUp --self-update${reset}"
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

add_script_to_global_path(){
    clear -x
    title
    if curl -s https://raw.githubusercontent.com/Heavybullets8/heavy_script/main/functions/deploy.sh | bash ;then
        echo
        echo -e "${green}HeavyScript has been added to your global path${reset}"
        echo 
        echo -e "${bold}Terminal Emulator${reset}"
        echo -e "${bold}-----------------${reset}"
        echo -e "You can now run heavyscript by just typing ${blue}heavyscript${reset}"
        echo -e "Example: ${blue}heavyscript -b 14 -rsp --self-update -u 10${reset}"
        echo -e "Example: ${blue}heavyscript --logs${reset}"
        echo
        echo -e "${bold}CronJobs${reset}"
        echo -e "${bold}--------${reset}"
        echo -e "CronJobs still require the entire path, and prefaced with ${blue}bash ${reset}"
        echo -e "Example of my personal cron: ${blue}bash /root/heavy_script/heavy_script.sh -b 14 -rsp --self-update -u 10${reset}"
        echo -e "It is highly recommended that you update your cron to use the new path"
        echo
        echo -e "${bold}Note${reset}"
        echo -e "${bold}----${reset}"
        echo -e "HeavyScript has been redownloaded to: ${blue}/root/heavy_script${reset}"
        echo -e "It is recommended that you remove your old copy of HeavyScript"
        echo -e "If you keep your old copy, you'll have to update both, manage both etc."
    else
        echo -e "${red}Failed to add HeavyScript to your global path${reset}"
    fi
}
