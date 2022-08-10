#!/bin/bash


cmd_to_container(){
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
search=$(k3s crictl ps -a -s running | sed -E 's/([0-9]*|About)[[:space:]][a-z]{2,5}[[:space:]](hour)?[[:space:]]?ago//')
mapfile -t pod_id < <(echo "$search" | grep -E "[[:space:]]$app_name([[:space:]]|-([-[:alnum:]])*[[:space:]])" | awk '{print $(NF)}')
count=0
for pod in "${pod_id[@]}"
do
    mapfile -t containers < <(echo "$search" | grep "$pod" | awk '{print $4}') 
    ((count++))
done

if [[ $count == 1 ]]; then
    container=$(echo "$search" | grep "${pod_id[*]}" | awk '{print $4}')
    container_id=$(echo "$search" | grep -E "[[:space:]]${container}[[:space:]]" | awk '{print $1}')
elif [[ "${#containers[@]}" == 0  ]]; then
    echo -e "No containers available\nAre you sure the application in running?"
    exit
else
    while true
    do
        clear -x
        title
        cont_search=$(
        for i in "${containers[@]}"
        do
            echo "$i"
        done | nl -s ") " | column -t
        )
        echo "$cont_search"
        echo
        echo "0)  Exit"
        read -rt 120 -p "Choose a container by number: " selection || { echo -e "\nFailed to make a selection in time" ; exit; }
        if [[ $selection == 0 ]]; then
            echo "Exiting.."
            exit
        elif ! echo -e "$cont_search}" | grep -qs ^"$selection)" ; then
            echo "Error: \"$selection\" was not an option.. Try again"
            sleep 3
            continue
        else
            break
        fi
    done
    container=$(echo "$cont_search" | grep ^"$selection)" | awk '{print $2}')
    container_id=$(echo "$search" | grep -E "[[:space:]]${container}[[:space:]]" | awk '{print $1}')
fi
while true
do
    clear -x
    title
    echo "App Name: $app_name"
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
            read -rt 120 -p "What command do you want to run?: " command || { echo -e "\nFailed to make a selection in time" ; exit; }
            k3s crictl exec -it "$container_id" $command
            break
            ;;
        2)
            clear -x
            title
            if ! k3s crictl exec -it "$container_id" /bin/bash 2>/dev/null; then
                k3s crictl exec -it "$container_id" /bin/sh 2>/dev/null || echo "This container does not accept shell access, try a different one."
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