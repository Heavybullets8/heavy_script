#!/bin/bash


cmd_to_container(){
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

    if [[ "$1" == "logs" ]]; then
        echo "Logs to Container Menu"
        echo "----------------------"
    else
        echo "Command to Container Menu"
        echo "-------------------------"
    fi

    for i in "${!app_map[@]}"; do
        printf "%d) %s\n" "$i" "${app_map[$i]}"
    done | sort -n
    echo
    echo "0)  Exit"
    read -r -t 120 -p "Please type a number: " selection || { echo -e "\nFailed to make a selection in time" ; exit; }

    # Validate selection
    if [[ $selection == 0 ]]; then
        echo "Exiting.."
        exit
    elif ! [[ $selection =~ ^[0-9]+$ ]] || ! [[ ${app_map[$selection]} ]]; then
        echo "Error: \"$selection\" was not an option.. Try again"
        sleep 3
        continue
    else
        break
    fi
done



rm cont_file 2> /dev/null
mapfile -t pod_id < <(k3s crictl pods -s ready --namespace ix | grep -v "[[:space:]]svclb-" | grep -E "[[:space:]]ix-${app_map[$selection]}[[:space:]]" | awk '{print $1}')
search=$(k3s crictl ps -a -s running | sed -E 's/[[:space:]]([0-9]*|About)[a-z0-9 ]{5,12}ago[[:space:]]//')
for pod in "${pod_id[@]}"
do
    echo "$search" | grep "$pod" >> cont_file
done
mapfile -t containers < <(sort -u cont_file 2> /dev/null)
case "${#containers[@]}" in
    0)
        echo -e "No containers available\nAre you sure the application in running?"
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
            echo "Available Containers"
            echo "--------------------"
            cont_search=$(
            for i in "${containers[@]}"
            do
                echo "$i" | awk '{print $4}'
            done | nl -s ") " | column -t
            )
            echo "$cont_search"
            echo
            echo "0)  Exit"
            read -rt 120 -p "Choose a container by number: " selection || { echo -e "\nFailed to make a selection in time" ; exit; }
            if [[ $selection == 0 ]]; then
                echo "Exiting.."
                exit
            elif ! echo -e "$cont_search" | grep -qs ^"$selection)" ; then
                echo "Error: \"$selection\" was not an option.. Try again"
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

if [[ $logs == true || $1 == "logs" ]];
then
    # ask for number of lines to display
    while true
    do
        clear -x
        title
        echo "App Name: ${app_map[$selection]}"
        echo "Container: $container"
        echo
        read -rt 120 -p "How many lines of logs do you want to display?: " lines || { echo -e "\nFailed to make a selection in time" ; exit; }
        if ! [[ $lines =~ ^[0-9]+$ ]]; then
            echo "Error: \"$lines\" was not a number.. Try again"
            sleep 3
            continue
        else
            break
        fi
    done

    k3s crictl logs -f "$container_id"
    exit
fi


while true
do
    clear -x
    title
    echo "App Name: ${app_map[$selection]}"
    echo "Container: $container"
    echo
    echo "1)  Run a single command"
    echo "2)  Open Shell"
    echo
    echo "0)  Exit"
    read -rt 120 -p "Please choose an option: " selection || { echo -e "\nFailed to make a selection in time" ; exit; }
    case $selection in
        0)
            echo "Exiting.."
            exit
            ;;
        1)
            clear -x 
            title
            read -rt 500 -p "What command do you want to run?: " command || { echo -e "\nFailed to make a selection in time" ; exit; }
            # shellcheck disable=SC2086
            # Quoting $command as suggested, causes the k3s command to fail
            k3s crictl exec -it "$container_id" $command
            break
            ;;
        2)
            clear -x
            title
            if ! k3s crictl exec -it "$container_id" bash -c '[[ -e /bin/bash ]] && exec /bin/bash || exec /bin/sh'; then
                echo "This container does not accept shell access, try a different one."
            fi
            break
            ;;
        *)
            echo "That was not an option.. Try again"
            sleep 3
            ;;
    esac
done

}
export -f cmd_to_container