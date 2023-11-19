#!/bin/bash

cmd_get_app_names() {
    app_names=$(k3s crictl pods -s ready --namespace ix | 
                sed -E 's/[[:space:]]([0-9]*|About)[a-z0-9 ]{5,12}ago[[:space:]]//' | 
                sed '1d' | 
                awk '{print $4}' | 
                cut -c4- | 
                sort -u)
    num=1
    for app in $app_names; do
        app_map[num]=$app
        num=$((num+1))
    done
}
export -f cmd_get_app_names

cmd_check_app_names() {
    # Check if there are any apps
    if [ -z "$app_names" ]; then
        echo -e "${yellow}There are no applications available"
        exit 0
    fi
}

cmd_header() {
    clear -x
    title 

    if [[ $1 == "logs" ]];then
        echo -e "${bold}Logs to Container Menu${reset}"
        echo -e "${bold}----------------------${reset}"
    else
        echo -e "${bold}Command to Container Menu${reset}"
        echo -e "${bold}-------------------------${reset}"
    fi
}

cmd_print_app_pod_container() {
    clear -x
    title

    if [[ -n $app_name ]]; then
        echo -e "${bold}App Name:${reset}  ${blue}${app_name}${reset}"
    fi

    if [[ -n $pod ]]; then
        echo -e "${bold}Pod:${reset}       ${blue}${pod}${reset}"
    fi

    if [[ -n $container ]]; then
        echo -e "${bold}Container:${reset} ${blue}${container}${reset}"
    fi
}

cmd_display_app_menu() {
    local selection
    # Display menu and get selection from user
    while true; do
        for i in "${!app_map[@]}"; do
            printf "%d) %s\n" "$i" "${app_map[$i]}"
        done | sort -n
        echo
        echo -e "0)  Exit"
        read -r -t 120 -p "Please type a number: " selection || { echo -e "${red}\nFailed to make a selection in time${reset}" ; exit; }

        # Validate selection
        if [[ $selection == 0 ]]; then
            echo -e "Exiting.."
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
}
export -f cmd_display_app_menu

cmd_get_pod() {
    local pods

    # Get all available pods in the namespace
    mapfile -t pods < <(k3s kubectl get pods --namespace ix-"$app_name" -o custom-columns=NAME:.metadata.name --no-headers | sort)

    if [[ ${#pods[@]} -eq 0 ]]; then
        echo -e "${red}There are no pods available${reset}"
        exit
    fi

    if [[ ${#pods[@]} -eq 1 ]]; then
        pod=${pods[0]}
    else
        cmd_print_app_pod_container
        echo
        echo -e "${bold}Available Pods:${reset}"
        for i in "${!pods[@]}"; do
            echo "$((i+1))) ${pods[$i]}"
        done
        echo
        echo "0) Exit"
        read -r -p "Choose a pod by number: " pod_selection

        if [[ $pod_selection == 0 ]]; then
            echo "Exiting..."
            exit
        fi

        pod=${pods[$((pod_selection-1))]}
    fi
}
export -f cmd_get_pod

cmd_get_container() {
    local containers

    # Get all available containers in the selected pod
    mapfile -t containers < <(k3s kubectl get pods "$pod" --namespace ix-"$app_name" -o jsonpath='{range.spec.containers[*]}{.name}{"\n"}{end}' | sort)

    if [[ ${#containers[@]} -eq 0 ]]; then
        echo -e "${red}There are no containers available${reset}"
        exit
    fi

    # If there's only one container, automatically choose it
    if [[ ${#containers[@]} == 1 ]]; then
        container=${containers[0]}
    else
        cmd_print_app_pod_container
        echo
        # Let the user choose a container
        echo -e "${bold}Available Containers:${reset}"
        for i in "${!containers[@]}"; do
            echo "$((i+1))) ${containers[$i]}"
        done
        echo
        echo "0) Exit"
        read -r -p "Choose a container by number: " container_selection

        if [[ $container_selection == 0 ]]; then
            echo "Exiting..."
            exit
        fi

        container=${containers[$((container_selection-1))]}
    fi
}
export -f cmd_get_container

cmd_execute_shell() {
    while true
    do
        cmd_print_app_pod_container
        echo 
        echo -e "If everything looks correct press enter/spacebar, or press ctrl+c to exit"
        read -rsn1 -d ' ' ; echo
        clear -x
        title
        k3s kubectl exec -n "ix-$app_name" "${pod}" -c "$container" -it -- sh -c '[ -e /bin/bash ] && exec /bin/bash || exec /bin/sh' 2> >(grep -v "command terminated with exit code 130" >&2)
        status=$?
        if [[ $status -eq 130 ]]; then
            echo "Received exit code 130, ignoring it."
        elif [[ $status -ne 0 ]]; then
            echo -e "${red}This container does not accept shell access, try a different one.${reset}"
        fi
        break
    done
}
export -f cmd_execute_shell

cmd_execute_logs() {
    local lines=500  # Default to 500 lines
    while true; do
        cmd_print_app_pod_container
        echo
        read -rt 120 -p "How many lines of logs do you want to display? (Default is 500, \"-1\" for all): " lines_input || { 
            echo -e "${red}\nFailed to make a selection in time${reset}" ; 
            exit; 
        }

        [[ -z "$lines_input" ]] || lines=$lines_input

        if ! [[ $lines =~ ^[0-9]+$|^-1$ ]]; then
            echo -e "${red}Error: ${blue}\"$lines\"${red} was not a number.. Try again${reset}"
            sleep 3
            continue
        else
            break
        fi
    done

    # Display logs
    if ! k3s kubectl logs --namespace "ix-$app_name" --tail "$lines" -f "$pod" -c "$container"; then
        echo -e "${red}Failed to retrieve logs for container: ${blue}$container${reset}"
        exit
    fi
    exit
}
export -f cmd_execute_logs

container_shell_or_logs(){
    mode="$1" 
    cmd_get_app_names
    cmd_check_app_names
    cmd_header "$mode"
    if [[ -z $2 ]]; then
        cmd_display_app_menu
    else
        app_name=$2
    fi
    cmd_get_pod
    cmd_get_container

    if [[ $mode == "logs" ]]; then
        cmd_execute_logs
    else
        cmd_execute_shell
    fi
}
