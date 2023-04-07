#!/bin/bash


delete_backup(){
    while true; do
        list_backups_func

        choose_restore "delete"

        #Confirm deletion
        while true
        do
            clear -x
            echo -e "${yellow}WARNING:\nYou CANNOT go back after deleting your restore point${reset}" 
            echo -e "\n\n${yellow}You have chosen:\n${blue}$restore_point\n\n${reset}"
            read -rt 120 -p "Would you like to proceed with deletion? (y/N): " yesno  || { echo -e "\n${red}Failed to make a selection in time${reset}" ; exit; }
            case $yesno in
                [Yy] | [Yy][Ee][Ss])
                    echo -e "\nDeleting $restore_point"
                    cli -c 'app kubernetes delete_backup backup_name=''"'"$restore_point"'"' &>/dev/null || { echo -e "${red}Failed to delete backup..${reset}"; exit; }
                    echo -e "${green}Sucessfully deleted${reset}"
                    break
                    ;;
                [Nn] | [Nn][Oo])
                    echo -e "Exiting"
                    exit
                    ;;
                *)
                    echo -e "${red}That was not an option, try again${reset}"
                    sleep 3
                    continue
                    ;;
            esac
        done

        #Check if there are more backups to delete
        while true
        do
            read -rt 120 -p "Delete more backups? (y/N): " yesno || { echo -e "\n${red}Failed to make a selection in time${reset}" ; exit; }
            case $yesno in
                [Yy] | [Yy][Ee][Ss])
                    break
                    ;;
                [Nn] | [Nn][Oo]|"")
                    exit
                    ;;
                *)
                    echo -e "${blue}$yesno ${red}was not an option, try again${reset}" 
                    sleep 2
                    continue
                    ;;

            esac

        done
    done
}