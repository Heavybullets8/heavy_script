#!/bin/bash


dns(){
    clear -x
    echo -e "${blue}Generating DNS Names..${reset}"

    # Pulling pod names
    k3s crictl pods --namespace ix -s Ready | sed -E 's/[[:space:]]([0-9]*|About)[a-z0-9 ]{5,12}ago[[:space:]]//' | grep -v 'svclb-' | sed '1d'  >> dns_file
    mapfile -t ix_name_array < <(< dns_file awk '{print $4}' | sort -u )

    # Pulling all ports
    all_ports=$(k3s kubectl get service -A)

    clear -x
    count=0
    for i in "${ix_name_array[@]}"
    do
        [[ count -le 0 ]] && echo -e "\n"
        full_app_name=$(grep -E "\s$i\s" "dns_file" | awk '{print $3}' | sed 's/-[^-]*-[^-]*$//' | sed 's/-0//' | head -n 1)
        app_name=$(echo "$i" | cut -c 4-)
        port=$(echo "$all_ports" | grep -E "\s$full_app_name\s" | awk '{print $6}' | grep -Eo "^[[:digit:]]+{1}")
        if ((count % 2 == 0)); then
            echo -e "\033[90m$app_name $full_app_name.$i.svc.cluster.local $port${reset}"
        else
            echo -e "$app_name $full_app_name.$i.svc.cluster.local $port"
        fi
        ((count++))
    done | nl -s ") " -b t | sed '0,/\s\s\s/{s/\s\s\s/- ---- -------- ----/}'| column -t -N "#,Name,DNS_Name,Port"
    rm dns_file
}
export -f dns