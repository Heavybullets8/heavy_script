#!/bin/bash

heavyscript_menu() {
    local misc_selection=""
    while true; do
        clear -x
        title
        echo -e "${bold}HeavyScript Options Menu${reset}"
        echo -e "${bold}------------------------${reset}"
        echo -e "1)  Self Update"
        echo -e "2)  Choose Branch"
        echo -e "3)  Add Script to Global Path"
        echo -e "${gray}This will download the one liner, and add it to your global path, you only need to do this once.${reset}"
        echo
        echo -e "9)  Back to Main Menu"
        echo -e "0)  Exit"
        read -rt 120 -p "Please select an option by number: " misc_selection || { echo -e "${red}\nFailed to make a selection in time${reset}" ; exit; }

        case $misc_selection in
            0)
                echo -e "Exiting.."
                exit
                ;;
            1)
                self_update
                exit
                ;;
            2)
                choose_branch
                exit
                ;;
            3)
                add_script_to_global_path
                exit
                ;;
            9)
                # Break the loop to go back to the main menu
                break
                ;;
            *)
                echo -e "${blue}\"$misc_selection\"${red} was not an option, please try again${reset}"
                sleep 3
                ;;
        esac
    done
}
