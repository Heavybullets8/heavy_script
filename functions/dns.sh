#!/bin/bash

dns(){
    clear -x
    echo -e "${blue}Generating DNS Names..${reset}"

    # Pulling pod names
    if ! k3s crictl pods --namespace ix -s Ready | 
                    sed -E 's/[[:space:]]([0-9]*|About)[a-z0-9 ]{5,12}ago[[:space:]]//' |
                    grep -v 'svclb-' |
                    sed '1d' > dns_file; then
        echo -e "${red}Error: failed to retrieve pod names${reset}" >&2
        return 1
    fi
    mapfile -t ix_name_array < <(< dns_file awk '{print $4}' | sort -u )

    # Exit if there are no applications ready
    if [ ${#ix_name_array[@]} -eq 0 ]; then
        echo -e "${red}There are no applications ready${reset}"
        exit
    fi

    # Pulling all ports
    if ! all_ports=$(k3s kubectl get service -A); then
        echo -e "${red}Error: failed to retrieve port information${reset}" >&2
        return 1
    fi

    clear -x
    output=""
    headers="${blue}App Name\tDNS Name\tPort${reset}"
    output+="$headers\n"
    for i in "${ix_name_array[@]}"
    do
        full_app_name=$(grep -E "\s$i\s" "dns_file" | 
                        awk '{print $3}' | 
                        sed 's/-[^-]*-[^-]*$//' | 
                        sed 's/-0//' | 
                        head -n 1)
        app_name=$(echo -e "$i" | cut -c 4-)
        port=$(echo -e "$all_ports" | 
               grep -E "\s$full_app_name\s" | 
               awk '{print $6}' | 
               grep -Eo "^[[:digit:]]+{1}")
        count=$((count + 1))
        if (( count % 2 == 0 )); then
            color="\033[0m"
        else
            color="\033[38;5;7m"
        fi
        line="${color}$app_name\t$full_app_name.$i.svc.cluster.local\t$port${reset}"
        output+="$line\n"
    done
    echo -e "$output" | column -t -s $'\t'
    rm dns_file
}
export -f dns
