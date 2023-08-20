#!/bin/bash


mount_prompt(){
    while true
    do
        clear -x
        title
        echo -e "${bold}PVC Mount Menu${reset}"
        echo -e "${bold}--------------${reset}"
        echo -e "1)  Mount"
        echo -e "2)  Unmount"
        echo
        echo -e "0)  Exit"
        read -rt 120 -p "Please type a number: " selection || { echo -e "\n${red}Failed to make a selection in time${reset}" ; exit; }
        case $selection in
            0)
                echo -e "Exiting.."
                exit
                ;;
            1)
                mount_app_func
                exit
                ;;
            2)
                unmount_app_func
                exit
                ;;
            *)
                echo -e "${red}Invalid selection, ${blue}\"$selection\"${red} was not an option${reset}" 
                sleep 3
                continue
                ;;
        esac
    done
}