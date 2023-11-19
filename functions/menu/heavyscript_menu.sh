#!/bin/bash

heavyscript_menu(){
    while [[ $misc_selection != true ]]
    do
        clear -x
        title
        echo -e "${bold}HeavyScript Options Menu${reset}"
        echo -e "${bold}------------------------${reset}"
        echo -e "1)  Self Update"
        echo -e "2)  Choose Branch"
        echo -e "3)  Add Script to Global Path"
        echo -e "${gray}This will download the one liner, and add it to your global path, you only need to do this once.${reset} "
        echo
        echo -e "0)  Exit"
        read -rt 120 -p "Please select an option by number: " misc_selection || { echo -e "${red}\nFailed to make a selection in time${reset}" ; exit; }
        case $misc_selection in
            0)
                echo -e "Exiting.."
                exit
                ;;
            1)
                misc_selection=true
                self_update
                ;;
            2)
                misc_selection=true
                choose_branch
                ;;
            3)
                misc_selection=true
                add_script_to_global_path
                ;;
            *)
                echo -e "${blue}\"$selection\"${red} was not an option, please try again${reset}"
                sleep 3
                continue
                ;;
        esac
    done
}