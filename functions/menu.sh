#!/bin/bash

menu(){
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
echo "9)  Command to Container"
echo
echo "0)  Exit"
read -rt 120 -p "Please select an option by number: " selection

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
        read -rt 120 -p "What is the maximun number of backups you would like?: " number_of_backups || echo "Failed to make a selection"
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
            read -rt 120 -p "Type the Number or Flag: " current_selection || { echo -e "\nFailed to make a selection in time" ; exit; }
            case $current_selection in
                0 | [Ee][Xx][Ii][Tt])
                    echo "Exiting.."
                    exit
                    ;;
                1 | -U) 
                    while true
                    do
                        echo -e "\nHow many applications do you want updating at the same time?"
                        read -rt 120 -p "Please type an integer greater than 0: " up_async || { echo -e "\nFailed to make a selection in time" ; exit; }
                        if [[ $up_async == 0 ]]; then
                            echo "Error: \"$up_async\" is less than 1"
                            echo "NOT adding it to the list"
                            sleep 3
                            continue
                        elif ! [[ $up_async =~ ^[0-9]+$  ]]; then
                            echo "Error: \"$up_async\" is invalid, it needs to be an integer"
                            echo "NOT adding it to the list"
                            sleep 3
                            continue
                        else
                            update_selection+=("-U" "$up_async")
                            break
                        fi
                    done
                    break
                    ;;
                2 | -u)
                    while true
                    do
                        echo -e "\nHow many applications do you want updating at the same time?"
                        read -rt 120 -p "Please type an integer greater than 0: " up_async || { echo -e "\nFailed to make a selection in time" ; exit; }
                        if [[ $up_async == 0 ]]; then
                            echo "Error: \"$up_async\" is less than 1"
                            echo "NOT adding it to the list"
                            sleep 3
                            continue
                        elif ! [[ $up_async =~ ^[0-9]+$  ]]; then
                            echo "Error: \"$up_async\" is invalid, it needs to be an integer"
                            echo "NOT adding it to the list"
                            sleep 3
                            continue
                        else
                            update_selection+=("-u" "$up_async")
                            break
                        fi
                    done
                    break
                    ;;
                *)
                    echo "$current_selection was not an option, try again" && sleep 3
                    continue
                    ;;
            esac
        done
        while true 
        do
            clear -x
            title
            echo "Update Options"
            echo "--------------"
            echo "1) -r | Roll-back applications if they fail to update"
            echo "2) -i | Add application to ignore list"
            echo "3) -S | Shutdown applications prior to updating"
            echo "4) -v | verbose output"
            echo "5) -t | Set a custom timeout in seconds when checking if either an App or Mountpoint correctly Started, Stopped or (un)Mounted. Defaults to 500 seconds"
            echo
            echo "Additional Options"
            echo "------------------"
            echo "6) -b | Back-up your ix-applications dataset, specify a number after -b"
            echo "7) -s | sync catalog"
            echo "8) -p | Prune unused/old docker images"
            echo "9) --self-update | Updates HeavyScript prior to running any other commands"
            echo
            echo "99) Remove Update Options, Restart"
            echo "00) Done making selections, proceed with update"
            echo 
            echo "0) Exit"
            echo 
            echo "Current Choices"
            echo "---------------"
            echo "bash heavy_script.sh ${update_selection[*]}"
            echo
            read -rt 600 -p "Type the Number or Flag: " current_selection || { echo -e "\nFailed to make a selection in time" ; exit; }
            case $current_selection in
                0 | [Ee][Xx][Ii][Tt])
                    echo "Exiting.."
                    exit
                    ;;
                00)
                    clear -x
                    echo "Running \"bash heavy_script.sh ${update_selection[*]}\""
                    echo
                    exec bash "$script_name" "${update_selection[@]}"
                    exit
                    ;;
                1 | -r)
                    printf '%s\0' "${update_selection[@]}" | grep -Fxqz -- "-r" && echo -e "\"-r\" is already on here, skipping" && sleep 3 && continue #If option is already on there, skip it
                    update_selection+=("-r")
                    ;;
                2 | -i)
                    read -rt 120 -p "What is the name of the application we should ignore?: " up_ignore || { echo -e "\nFailed to make a selection in time" ; exit; }
                    ! [[ $up_ignore =~ ^[a-zA-Z]([-a-zA-Z0-9]*[a-zA-Z0-9])?$ ]] && echo -e "Error: \"$up_ignore\" is not a possible option for an application name" && sleep 3 && continue
                    update_selection+=("-i" "$up_ignore")
                    ;;
                3 | -S)
                    printf '%s\0' "${update_selection[@]}" | grep -Fxqz -- "-S" && echo -e "\"-S\" is already on here, skipping" && sleep 3 && continue #If option is already on there, skip it
                    update_selection+=("-S")
                    ;;
                4 | -v)
                    printf '%s\0' "${update_selection[@]}" | grep -Fxqz -- "-v" && echo -e "\"-v\" is already on here, skipping" && sleep 3 && continue #If option is already on there, skip it
                    update_selection+=("-v")
                    ;;
                5 | -t)
                    printf '%s\0' "${update_selection[@]}" | grep -Fxqz -- "-t" && echo -e "\"-t\" is already on here, skipping" && sleep 3 && continue #If option is already on there, skip it
                    echo "What do you want your timeout to be?"
                    read -rt 120 -p "Please type an integer: " up_timeout || { echo -e "\nFailed to make a selection in time" ; exit; }
                    ! [[ $up_timeout =~ ^[0-9]+$ ]] && echo -e "Error: \"$up_timeout\" is invalid, it needs to be an integer\nNOT adding it to the list" && sleep 3 && continue
                    update_selection+=("-t" "$up_timeout")
                    ;;
                6 | -b)
                    printf '%s\0' "${update_selection[@]}" | grep -Fxqz -- "-b" && echo -e "\"-b\" is already on here, skipping" && sleep 3 && continue #If option is already on there, skip it
                    echo "Up to how many backups should we keep?"
                    read -rt 120 -p "Please type an integer: " up_backups || { echo -e "\nFailed to make a selection in time" ; exit; }
                    ! [[ $up_backups =~ ^[0-9]+$ ]] && echo -e "Error: \"$up_backups\" is invalid, it needs to be an integer\nNOT adding it to the list" && sleep 3 && continue
                    [[ $up_backups == 0 ]] && echo -e "Error: Number of backups cannot be 0\nNOT adding it to the list" && sleep 3 && continue
                    update_selection+=("-b" "$up_backups")
                    ;;
                7 | -s)
                    printf '%s\0' "${update_selection[@]}" | grep -Fxqz -- "-s" && echo -e "\"-s\" is already on here, skipping" && sleep 3 && continue #If option is already on there, skip it
                    update_selection+=("-s")
                    ;;
                8 | -p)
                    printf '%s\0' "${update_selection[@]}" | grep -Fxqz -- "-p" && echo -e "\"-p\" is already on here, skipping" && sleep 3 && continue #If option is already on there, skip it
                    update_selection+=("-p")
                    ;;
                9 | --self-update )
                    printf '%s\0' "${update_selection[@]}" | grep -Fxqz -- "--self-update" && echo -e "\"--self-update\" is already on here, skipping" && sleep 3 && continue #If option is already on there, skip it
                    update_selection+=("--self-update")      
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
                    sleep 3
                    continue
                    ;;
                *)
                    echo "\"$current_selection\" was not an option, try again" && sleep 3 && continue 
                    ;;
            esac
        done
        ;;

    9)
        app_name=$(k3s kubectl get pods -A | awk '{print $1}' | sort -u | grep -v "system" | sed '1d' | sed 's/^[^-]*-//' | nl -s ") " | column -t)
        while true
        do
            clear -x
            title 
            echo "$app_name"
            echo
            echo "0)  Exit"
            read -rt 120 -p "Please type a number: " selection || { echo -e "\nFailed to make a selection in time" ; exit; }
            if [[ $selection == 0 ]]; then
                echo "Exiting.."
                exit
            elif ! echo -e "$app_name" | grep -qs ^"$selection)" ; then
                echo "Error: \"$selection\" was not an option.. Try again"
                sleep 3
                continue
            else
                break
            fi
        done
        app_name=$(echo -e "$app_name" | grep ^"$selection)" | awk '{print $2}')
        search=$(k3s crictl ps -a -s running)
        mapfile -t pod_id < <(echo "$search" | grep -E " $app_name(-|[[:alnum:]])*[[:space:]]" | awk '{print $9}')

        containers=$(
        for pod in "${pod_id[@]}"
        do
            echo "$search" | grep "$pod" | awk '{print $7}'
        done | nl -s ") " | column -t) 
        while true
        do
            clear -x
            title
            echo "$containers"
            echo
            echo "0)  Exit"
            read -rt 120 -p "Choose a container by number: " selection || { echo -e "\nFailed to make a selection in time" ; exit; }
            if [[ $selection == 0 ]]; then
                echo "Exiting.."
                exit
            elif ! echo -e "$containers" | grep -qs ^"$selection)" ; then
                echo "Error: \"$selection\" was not an option.. Try again"
                sleep 3
                continue
            else
                break
            fi
        done
        container=$(echo "$containers" | grep ^"$selection)" | awk '{print $2}')
        container_id=$(echo "$search" | grep "$container" | awk '{print $1}')
        clear -x
        title
        echo "App Name: $app_name"
        echo "Container $container"
        echo
        echo "0)  Exit"
        read -rt 120 -p "What command would you like to run?: " command || { echo -e "\nFailed to make a selection in time" ; exit; }
        [[ $command == 0 ]] && echo "Exiting.." && exit
        k3s crictl exec "$container_id" $command
        container=$(echo -e "$app_name" | grep ^"$selection)" | awk '{print $2}')
        ;;
    *)
        echo "\"$selection\" was not an option, please try agian" && sleep 3 && menu
        ;;
esac
echo
}
export -f menu
