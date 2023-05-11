#!/bin/bash


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
        echo -e "Example: ${blue}heavyscript update -b 14 -rsp --self-update -c 10${reset}"
        echo -e "Example: ${blue}heavyscript pod --logs${reset}"
        echo -e "Example: ${blue}heavyscript app --restart${reset}"
        echo -e "Example: ${blue}heavyscript git --branch${reset}"
        echo -e "Example: ${blue}heavyscript backup --create 14${reset}"
        echo
        echo -e "${bold}CronJobs${reset}"
        echo -e "${bold}--------${reset}"
        echo -e "CronJobs still require the entire path, and prefaced with ${blue}bash ${reset}"
        echo -e "Example of my personal cron: ${blue}bash $HOME/heavy_script/heavy_script.sh update -b 14 -rsp --self-update -c 10${reset}"
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