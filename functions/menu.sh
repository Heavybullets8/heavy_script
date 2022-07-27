#!/bin/bash

menu(){
script=$(readlink -f "$0")
script_path=$(dirname "$script")
script_name="heavy_script.sh"
cd "$script_path" || exit
clear -x
title
echo "1)  Help"
echo "2)  List DNS Names"
echo "3)  Mount and Unmount PVC storage"
echo "4)  Create a Backup"
echo "5)  Restore a Backup"
echo "6)  Delete a Backup"
echo "7)  Update HeavyScript"
echo "8)  Update Applications"
echo
echo "0)  Exit"
read -rt 600 -p "Please select an option by number: " selection

case $selection in
    0)
        exit
        ;;
    1)
        help="true"
        ;;
    2)
        dns="true"
        ;;
    3)
        mount="true"
        ;;
    4)
        read -rt 600 -p "What is the maximun number of backups you would like?: " number_of_backups
        backup="true"
        ;;
    5)
        restore="true"
        ;;
    6)
        deleteBackup="true"
        ;;
    7)
        self_update="true"
        ;;
    8)
        while true 
        do
            clear -x
            title
            echo "Choose Your Update Type"
            echo "-----------------------"
            echo "1) -U | Update all applications, ignores versions"
            echo "2) -u | Update all applications, does not update Major releases"
            echo
            echo "0) Exit"
            echo
            read -rt 600 -p "Please type the number associated with the flag above: " current_selection
            if [[ $current_selection == 1 ]]; then
                echo -e "\nHow many applications do you want updating at the same time?"
                read -rt 600 -p "Please type an integer greater than 0: " up_async
                if [[ $up_async == 0 ]]; then
                    echo "Error: \"$up_async\" is less than 1"
                    echo "NOT adding it to the list"
                    sleep 5
                    continue
                elif ! [[ $up_async =~ ^[0-9]+$  ]]; then
                    echo "Error: \"$up_async\" is invalid, it needs to be an integer"
                    echo "NOT adding it to the list"
                    sleep 5
                    continue
                else
                    update_selection+=("-U" "$up_async")
                    break
                fi
            elif [[ $current_selection == 2 ]]; then
                echo -e "\nHow many applications do you want updating at the same time?"
                read -rt 600 -p "Please type an integer greater than 0: " up_async
                if [[ $up_async == 0 ]]; then
                    echo "Error: \"$up_async\" is less than 1"
                    echo "NOT adding it to the list"
                    sleep 5
                    continue
                elif ! [[ $up_async =~ ^[0-9]+$  ]]; then
                    echo "Error: \"$up_async\" is invalid, it needs to be an integer"
                    echo "NOT adding it to the list"
                    sleep 5
                    continue
                else
                    update_selection+=("-u" "$up_async")
                    break
                fi
            elif [[ $current_selection == 0 ]]; then
                echo "Exiting.." 
                exit
            else
                echo "$current_selection was not an option, try again" && sleep 5
                continue
            fi
        done
        while true 
        do
            clear -x
            title
            echo "Choose Your Update Options"
            echo "--------------------------"
            echo "1) -b | Back-up your ix-applications dataset, specify a number after -b"
            echo "2) -i | Add application to ignore list, one by one, see example below."
            echo "3) -r | Roll-back applications if they fail to update"
            echo "4) -S | Shutdown applications prior to updating"
            echo "5) -v | verbose output"
            echo "6) -t | Set a custom timeout in seconds when checking if either an App or Mountpoint correctly Started, Stopped or (un)Mounted. Defaults to 500 seconds"
            echo "7) -s | sync catalog"
            echo "8) -p | Prune unused/old docker images"
            echo
            echo "99) Remove Update Options, Restart"
            echo "00) Done making selections, proceed with update"
            echo 
            echo "Current Choices"
            echo "---------------"
            echo "bash heavy_script.sh ${update_selection[*]}"
            echo
            read -rt 600 -p "Please type the number associated with the flag above: " current_selection

            case $current_selection in
                00)
                    clear -x
                    echo "Running \"bash heavy_script.sh ${update_selection[*]}\""
                    echo
                    exec bash "$script_name" "${update_selection[@]}"
                    exit
                    ;;
                1 | -b)
                    printf '%s\0' "${update_selection[@]}" | grep -Fxqz -- "-b" && echo -e "\"-b\" is already on here, skipping" && sleep 5 && continue #If option is already on there, skip it
                    echo "Up to how many backups should we keep?"
                    read -rt 600 -p "Please type an integer: " up_backups
                    ! [[ $up_backups =~ ^[0-9]+$ ]] && echo -e "Error: \"$up_backups\" is invalid, it needs to be an integer\nNOT adding it to the list" && sleep 5 && continue
                    [[ $up_backups == 0 ]] && echo -e "Error: Number of backups cannot be 0\nNOT adding it to the list" && sleep 5 && continue
                    update_selection+=("-b" "$up_backups")
                    ;;
                2 | -i)
                    read -rt 600 -p "What is the name of the application we should ignore?: " up_ignore
                    update_selection+=("-i" "$up_ignore")
                    ;;
                3 | -r)
                    printf '%s\0' "${update_selection[@]}" | grep -Fxqz -- "-r" && echo -e "\"-r\" is already on here, skipping" && sleep 5 && continue #If option is already on there, skip it
                    update_selection+=("-r")
                    
                    ;;
                4 | -S)
                    printf '%s\0' "${update_selection[@]}" | grep -Fxqz -- "-S" && echo -e "\"-S\" is already on here, skipping" && sleep 5 && continue #If option is already on there, skip it
                    update_selection+=("-S")
                    ;;
                5 | -v)
                    printf '%s\0' "${update_selection[@]}" | grep -Fxqz -- "-v" && echo -e "\"-v\" is already on here, skipping" && sleep 5 && continue #If option is already on there, skip it
                    update_selection+=("-v")
                    ;;
                6 | -t)
                    printf '%s\0' "${update_selection[@]}" | grep -Fxqz -- "-t" && echo -e "\"-t\" is already on here, skipping" && sleep 5 && continue #If option is already on there, skip it
                    echo "What do you want your timeout to be?"
                    read -rt 600 -p "Please type an integer: " up_timeout
                    ! [[ $up_timeout =~ ^[0-9]+$ ]] && echo -e "Error: \"$up_timeout\" is invalid, it needs to be an integer\nNOT adding it to the list" && sleep 5 && continue
                    update_selection+=("-t" "$up_timeout")
                    ;;
                7 | -s)
                    printf '%s\0' "${update_selection[@]}" | grep -Fxqz -- "-s" && echo -e "\"-s\" is already on here, skipping" && sleep 5 && continue #If option is already on there, skip it
                    update_selection+=("-s")
                    ;;
                8 | -p)
                    printf '%s\0' "${update_selection[@]}" | grep -Fxqz -- "-p" && echo -e "\"-p\" is already on here, skipping" && sleep 5 && continue #If option is already on there, skip it
                    update_selection+=("-p")
                    ;;
                99)
                    count=2
                    echo "restarting"
                    for i in "${update_selection[@]:2}"
                    do
                        unset "update_selection[$count]"
                        echo "$i removed"
                        ((count++))
                    done
                    sleep 5
                    continue
                    ;;
                *)
                    echo "\"$current_selection\" was not an option, try again" && sleep 5 && continue 
                    ;;
            esac
        done
        ;;
    *)
        echo "\"$selection\" was not an option, please try agian" && sleep 5 && menu
        ;;
esac
echo
}
export -f menu