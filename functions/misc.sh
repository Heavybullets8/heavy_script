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
    if [[ $help == true ]]; then
        clear -x
    fi
    echo -e "${bold}Access the HeavyScript Menu${reset}"
    echo -e "${bold}---------------------------${reset}"
    echo -e "heavy_script"
    echo
    echo -e "${bold}Utilities${reset}"
    echo -e "${bold}---------${reset}"
    echo -e "--mount         | Initiates mounting feature, choose between unmounting and mounting PVC data"
    echo -e "--restore       | Opens a menu to restore a \"heavy_script\" backup that was taken on your \"ix-applications\" dataset"
    echo -e "--delete-backup | Opens a menu to delete backups on your system"
    echo -e "--dns           | list all of your applications DNS names and their web ports"
    echo -e "--cmd           | Open a shell for one of your applications"
    echo -e "--logs          | Open the log file for one of your applications"
    echo 
    echo -e "${bold}Update Types${reset}"
    echo -e "${bold}------------${reset}"
    echo -e "-U    | Update all applications, ignores versions"
    echo -e "-U 5  | Same as above, but updates 5 applications at one time"
    echo -e "-u    | Update all applications, does not update Major releases"
    echo -e "-u 5  | Same as above, but updates 5 applications at one time"
    echo
    echo -e "${bold}Update Options${reset}"
    echo -e "${bold}--------------${reset}"
    echo -e "-r    | Roll-back applications if they fail to update"
    echo -e "-i    | Add application to ignore list, one by one, see example below."
    echo -e "-S    | Shutdown applications prior to updating"
    echo -e "-v    | verbose output"
    echo -e "-t 500| The amount of time HS will wait for an application to be ACTIVE. Defaults to 500 seconds"
    echo
    echo -e "${bold}Additional Options${reset}"
    echo -e "${bold}------------------${reset}"
    echo -e "-b 14 | Back-up your ix-applications dataset, specify a number after -b"
    echo -e "-s    | sync catalog"
    echo -e "-p    | Prune unused/old docker images"
    echo -e "--ignore-img  | Ignore container image updates"
    echo -e "--self-update | Updates HeavyScript prior to running any other commands"
    echo
    echo -e "${bold}Examples${reset}"
    echo -e "${bold}--------${reset}"
    echo -e "heavyscript -b 14 -i portainer -i arch -i sonarr -t 600 -vrsUp --self-update"
    echo -e "heavyscript -b 14 -i portainer -i arch -i sonarr -t 600 -vrsp -U 10 --self-update"
    echo -e "heavyscript-t 150 --mount"
    echo -e "heavyscript --dns"
    echo -e "heavyscript --restore"
    echo -e "heavyscript --delete-backup"
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
