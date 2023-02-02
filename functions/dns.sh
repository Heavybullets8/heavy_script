#!/bin/bash


dns(){
    clear -x
    echo -e "${blue}Generating DNS Names..${reset}"

    # Pulling pod names
    k3s crictl pods --namespace ix -s Ready | 
        sed -E 's/[[:space:]]([0-9]*|About)[a-z0-9 ]{5,12}ago[[:space:]]//' |
        grep -v 'svclb-' |
        sed '1d' > dns_file
    mapfile -t ix_name_array < <(< dns_file awk '{print $4}' | sort -u )

    # Pulling all ports
    all_ports=$(k3s kubectl get service -A)

    clear -x
    for i in "${ix_name_array[@]}"
    do
        full_app_name=$(grep -E "\s$i\s" "dns_file" | awk '{print $3}' | sed 's/-[^-]*-[^-]*$//' | sed 's/-0//' | head -n 1)
        app_name=$(echo "$i" | cut -c 4-)
        port=$(echo "$all_ports" | grep -E "\s$full_app_name\s" | awk '{print $6}' | grep -Eo "^[[:digit:]]+{1}")
        count=$((count + 1))
        if (( count % 2 == 0 )); then
            color="\033[0m"
        else
            color="\033[1;30m"
        fi
        echo -e "${color}$app_name $full_app_name.$i.svc.cluster.local $port\033[0m"
    done | column -t -N "App Name,DNS Name,Port"
    rm dns_file
}
export -f dns