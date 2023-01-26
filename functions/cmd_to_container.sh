#!/bin/bash


container_shell_or_logs(){
    # Store the app names and their corresponding numbers in a map
    declare -A app_map
    app_names=$(k3s crictl pods -s ready --namespace ix | sed -E 's/[[:space:]]([0-9]*|About)[a-z0-9 ]{5,12}ago[[:space:]]//' | sed '1d' | awk '{print $4}' | cut -c4- | sort -u)
    num=1
    for app in $app_names; do
        app_map[$num]=$app
        num=$((num+1))
    done

    # Display menu and get selection from user
    while true; do
        clear -x
        title 

        if [[ $logs == "true" || $1 == "logs" ]];then
            echo -e "${bold}Logs to Container Menu${reset}"
            echo -e "${bold}----------------------${reset}"
        else
            echo -e "${bold}Command to Container Menu${reset}"
            echo -e "${bold}-------------------------${reset}"
        fi

        for i in "${!app_map[@]}"; do
            printf "%d) %s\n" "$i" "${app_map[$i]}"
        done | sort -n
        echo
        echo "0)  Exit"
        read -r -t 120 -p "Please type a number: " selection || { echo -e "${red}\nFailed to make a selection in time${reset}" ; exit; }

        # Validate selection
        if [[ $selection == 0 ]]; then
            echo "Exiting.."
            exit
        elif ! [[ $selection =~ ^[0-9]+$ ]] || ! [[ ${app_map[$selection]} ]]; then
            echo -e "${red}Error: \"$selection\" was not an option.. Try again${reset}"
            sleep 3
            continue
        else
            break
        fi
    done

    app_name=${app_map[$selection]}

    rm cont_file 2> /dev/null
    mapfile -t pod_id < <(k3s crictl pods -s ready --namespace ix | grep -v "[[:space:]]svclb-" | grep -E "[[:space:]]ix-${app_name}[[:space:]]" | awk '{print $1}')
    search=$(k3s crictl ps -a -s running | sed -E 's/[[:space:]]([0-9]*|About)[a-z0-9 ]{5,12}ago[[:space:]]//')
    for pod in "${pod_id[@]}"
    do
        echo "$search" | grep "$pod" >> cont_file
    done
    mapfile -t containers < <(sort -u cont_file 2> /dev/null)
    case "${#containers[@]}" in
        0)
            echo -e "${red}No containers available\nAre you sure the application in running?${reset}"
            exit
            ;;
        1)
            container=$(grep "${pod_id[0]}" cont_file | awk '{print $4}')
            container_id=$(grep -E "[[:space:]]${container}[[:space:]]" cont_file | awk '{print $1}')
            ;;
        *)
            while true
            do
                clear -x
                title
                echo -e "${bold}Available Containers${reset}"
                echo -e "${bold}--------------------${reset}"
                cont_search=$(
                for i in "${containers[@]}"
                do
                    echo "$i" | awk '{print $4}'
                done | nl -s ") " | column -t
                )
                echo "$cont_search"
                echo
                echo "0)  Exit"
                read -rt 120 -p "Choose a container by number: " selection || { echo -e "${red}\nFailed to make a selection in time${reset}" ; exit; }
                if [[ $selection == 0 ]]; then
                    echo "Exiting.."
                    exit
                elif ! echo -e "$cont_search" | grep -qs ^"$selection)" ; then
                    echo -e "${red}Error: \"$selection\" was not an option.. Try again${reset}"
                    sleep 3
                    continue
                else
                    break
                fi
            done
            container=$(echo "$cont_search" | grep ^"$selection)" | awk '{print $2}')
            container_id=$(grep -E "[[:space:]]${container}[[:space:]]" cont_file | awk '{print $1}')
            ;;
    esac

    rm cont_file 2> /dev/null

    if [[ $logs == "true" || $1 == "logs" ]];
    then
        # ask for number of lines to display
        while true
        do
            clear -x
            title
            echo -e "${bold}App Name:${reset} ${blue}${app_name}${reset}"
            echo -e "${bold}Container:${reset} ${blue}$container${reset}"
            echo
            read -rt 120 -p "How many lines of logs do you want to display?(\"-1\" for all): " lines || { echo -e "${red}\nFailed to make a selection in time${reset}" ; exit; }
            if ! [[ $lines =~ ^[0-9]+$|^-1$ ]]; then
                echo -e "${red}Error: \"$lines\" was not a number.. Try again${reset}"
                sleep 3
                continue
            else
                break
            fi
        done

        # Display logs
        if ! k3s crictl logs --tail "$lines" -f "$container_id"; then
            echo -e "${red}Failed to retrieve logs for container: $container_id${reset}"
            exit
        fi
        exit
    fi


    while true
    do
        clear -x
        title
        echo -e "${bold}App Name:${reset} ${blue}${app_name}${reset}"
        echo -e "${bold}Container:${reset} ${blue}$container${reset}"
        echo
        echo "1)  Run a single command"
        echo "2)  Open Shell"
        echo
        echo "0)  Exit"
        read -rt 120 -p "Please choose an option: " selection || { echo -e "${red}\nFailed to make a selection in time${reset}" ; exit; }
        case $selection in
            0)
                echo "Exiting.."
                exit
                ;;
            1)
                clear -x 
                title
                read -rt 500 -p "What command do you want to run?: " command || { echo -e "${red}\nFailed to make a selection in time${reset}" ; exit; }
                # shellcheck disable=SC2086
                # Quoting $command as suggested, causes the k3s command to fail
                k3s crictl exec -it "$container_id" $command
                break
                ;;
            2)
                clear -x
                title
                if ! k3s crictl exec -it "$container_id" sh -c '[[ -e /bin/bash ]] && exec /bin/bash || exec /bin/sh'; then
                    echo -e "${red}This container does not accept shell access, try a different one.${reset}"
                fi
                break
                ;;
            *)
                echo -e "${red}That was not an option.. Try again${reset}"
                sleep 3
                ;;
        esac
    done
}
export -f container_shell_or_logs