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
    if (( "$version" >= 2310 )); then
        if ! cli -c 'app container config prune prune_options={"remove_unused_images": true}' &>/dev/null ; then
            echo -e "Failed to Prune Docker Images"
        else
            echo -e "Pruned Docker Images"
        fi
    elif (( "$version" >= 2212 )); then
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

    echo -e "${bold}HeavyScript Menu${reset}"
    echo -e "${bold}----------------${reset}"
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


add_script_to_global_path(){
    clear -x
    title
    # shellcheck source=/dev/null
    if curl -s https://raw.githubusercontent.com/Heavybullets8/heavy_script/main/functions/deploy.sh | bash && (source "$HOME/.bashrc" 2>/dev/null || true) && (source "$HOME/.zshrc" 2>/dev/null || true) ;then
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
        echo -e "Example of my personal cron: ${blue}bash $HOME/heavy_script/heavy_script.sh -b 14 -rsp --self-update -u 10${reset}"
        echo -e "It is highly recommended that you update your cron to use the new path"
        echo
        echo -e "${bold}Note${reset}"
        echo -e "${bold}----${reset}"
        echo -e "HeavyScript has been redownloaded to: ${blue}$HOME/heavy_script${reset}"
        echo -e "It is recommended that you remove your old copy of HeavyScript"
        echo -e "If you keep your old copy, you'll have to update both, manage both etc."
    else
        echo -e "${red}Failed to add HeavyScript to your global path${reset}"
    fi
}


wait_for_pods_to_stop() {
    local app_name timeout
    app_name="$1"
    timeout="$2"

    SECONDS=0
    while k3s kubectl get pods -n ix-"$app_name" -o=name | grep -qv -- '-cnpg-'; do
        if [[ "$SECONDS" -gt $timeout ]]; then
            return 1
        fi
        sleep 1
    done
}

get_app_status() {
    local app_name stop_type
    app_name="$1"
    stop_type="$2"

    if [[ "$stop_type" == "update" ]]; then
        grep "^$app_name," all_app_status | awk -F ',' '{print $2}'
    else
        cli -m csv -c 'app chart_release query name,status' | \
            grep -- "^$app_name," | \
            awk -F ',' '{print $2}'
    fi
}

stop_app() {
    local stop_type app_name timeout status count
    stop_type="$1"
    app_name="$2"
    timeout="${3:-300}"

    if k3s kubectl get pods -n ix-"$app_name" -o=name | grep -q -- '-cnpg-'; then
        if ! k3s kubectl get deployments,statefulsets -n ix-"$app_name" | grep -vE -- "(NAME|^$|-cnpg-)" | awk '{print $1}' | xargs -I{} k3s kubectl scale --replicas=0 -n ix-"$app_name" {} &>/dev/null; then
            return 1
        fi
        wait_for_pods_to_stop "$app_name" "$timeout" || return 1
    else
        for (( count=0; count<3; count++ )); do
            status=$(get_app_status "$app_name" "$stop_type")

            if [[ "$status" == "STOPPED" ]]; then
                return 0
            elif cli -c 'app chart_release scale release_name='\""$app_name"\"\ 'scale_options={"replica_count": 0}' &> /dev/null; then
                return 0
            else
                if [[ "$stop_type" == "update" ]]; then
                    before_loop=$(head -n 1 all_app_status)
                    until [[ $(head -n 1 all_app_status) != "$before_loop" ]]; do
                        sleep 1
                    done
                else
                    sleep 5
                fi
            fi
        done
    fi

    if [[ "$status" != "STOPPED" ]]; then
        return 1
    fi
}



