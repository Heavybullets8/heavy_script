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
search=$(k3s crictl ps -a -s running)
mapfile -t pod_id < <(echo "$search" | grep -E " $app_name([[:space:]]|-([-[:alnum:]])*[[:space:]])" | awk '{print $9}')
[[ "${#pod_id[@]}" == 0 ]] && echo -e "No containers available\nAre you sure the application in running?" && exit
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
container_id=$(echo "$search" | grep -E "[[:space:]]${container}[[:space:]]" | awk '{print $1}')
clear -x
title
echo "App Name: $app_name"
echo "Container: $container"
echo
echo "0)  Exit"
read -rt 120 -p "What command would you like to run?: " command || { echo -e "\nFailed to make a selection in time" ; exit; }
[[ $command == 0 ]] && echo "Exiting.." && exit
k3s crictl exec "$container_id" $command
container=$(echo -e "$app_name" | grep ^"$selection)" | awk '{print $2}')
}
export -f cmd_to_container