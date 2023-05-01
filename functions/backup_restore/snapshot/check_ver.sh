#!/bin/bash


check_restore_point_version() {
    ## Check the restore point, and ensure it is the same version as the current system ##
    # Boot Query
    boot_query=$(cli -m csv -c 'system bootenv query created,realname')

    # Get the date of system version and when it was updated
    current_version=$(cli -m csv -c 'system version' | awk -F '-' '{print $3}')
    when_updated=$(echo -e "$boot_query" | 
                   grep "$current_version", | 
                   sed -n 's/.*\([0-9]\{4\}-[0-9]\{2\}-[0-9]\{2\}\)T\([0-9]\{2\}:[0-9]\{2\}\).*/\1\2/p' | 
                   tr -d -- "-:")

    # Get the date of the chosen restore point
    # Extract the date information from the restore point string, which is formatted as "restore_point_<date>_<time>"
    restore_point_date=$(echo -e "$restore_point" | awk -F '_' '{print $2 $3 $4 $5 $6}' | tr -d "_")


    # Grab previous version
    previous_version=$(echo -e "$boot_query" | sort -nr | grep -A 1 "$current_version," | tail -n 1)

    # Compare the dates
    while (("$restore_point_date" < "$when_updated" ))
    do
        clear -x
        echo -e "The restore point you have chosen is from an older version of Truenas Scale"
        echo -e "This is not recommended, as it may cause issues with the system"
        echo -e "Either that, or your systems date is incorrect.."
        echo
        echo -e "${bold}Current SCALE Information:"
        echo -e "${bold}Version:${reset}       ${blue}$current_version${reset}"
        echo -e "${bold}When Updated:${reset}  ${blue}$(echo -e "$restore_point" | awk -F '_' '{print $2 "-" $3 "-" $4}')${reset}"
        echo
        echo -e "${bold}Restore Point SCALE Information:${reset}"
        echo -e "${bold}Version:${reset}       ${blue}$(echo -e "$previous_version" | awk -F ',' '{print $1}')${reset}"
        echo -e "${bold}When Updated:${reset}  ${blue}$(echo -e "$previous_version" | awk -F ',' '{print $2}' | awk -F 'T' '{print $1}')${reset}"
        echo
        read -rt 120 -p "Would you like to proceed? (y/N): " yesno || { echo -e "\n${red}Failed to make a selection in time${reset}" ; exit; }
            case $yesno in
                [Yy] | [Yy][Ee][Ss])
                    echo -e "${green}Proceeding..${reset}"
                    sleep 3
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
}