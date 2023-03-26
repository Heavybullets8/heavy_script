#!/bin/bash


choose_restore(){
    #select a restore point
    count=1
    while true
    do
        clear -x
        title
        if [[ "$1" == "delete" ]]; then
            echo -e "${bold}Choose a restore point to delete${reset}"
        else
            echo -e "${bold}Choose a restore point to restore${reset}"
        fi
        echo

        {
        if [[ ${#hs_tt_backups[@]} -gt 0 ]]; then
            echo -e "${bold}# HeavyScript/Truetool_Backups${reset}"
            # Print the HeavyScript and Truetool backups with numbers
            for ((i=0; i<${#hs_tt_backups[@]}; i++)); do
                echo -e "$count) ${hs_tt_backups[i]}"
                ((count++))
            done
        fi


        # Check if the system backups array is non-empty
        if [[ ${#system_backups[@]} -gt 0 ]]; then
            echo -e "\n${bold}# System_Backups${reset}"
            # Print the system backups with numbers
            for ((i=0; i<${#system_backups[@]}; i++)); do
                echo -e "$count) ${system_backups[i]}"
                ((count++))
            done
        fi


        # Check if the other backups array is non-empty
        if [[ ${#other_backups[@]} -gt 0 ]]; then
            echo -e "\n${bold}# Other_Backups${reset}"
            # Print the other backups with numbers
            for ((i=0; i<${#other_backups[@]}; i++)); do
                echo -e "$count) ${other_backups[i]}"
                ((count++))
            done 
        fi
        } | column -t -L

        echo
        echo -e "0)  Exit"
        # Prompt the user to select a restore point
        read -rt 240 -p "Please type a number: " selection || { echo -e "\n${red}Failed to make a selection in time${reset}" ; exit; }

        # Check if the user wants to exit
        if [[ $selection == 0 ]]; then
            echo -e "Exiting.." 
            exit
        # Check if the user's input is empty
        elif [[ -z "$selection" ]]; then 
            echo -e "${red}Your selection cannot be empty${reset}"
            sleep 3
            continue
        else
            # Check if the user's selection is a valid option
            found=0
            for point in "${restore_points[@]}"; do
                if grep -q "$selection)" <<< "$point"; then
                    found=1
                    break
                fi
            done

            # If the user's selection is not a valid option, inform them and prompt them to try again
            if [[ $found -eq 0 ]]; then
                echo -e "${red}Invalid Selection: ${blue}$selection${red}, was not an option${reset}"
                sleep 3
                continue
            fi
            # Extract the restore point from the array
            restore_point=${restore_points[$((selection-1))]#*[0-9]) }
        fi
        # Break out of the loop
        break
    done
}
export -f choose_restore