#!/bin/bash


# Clears screen and prints message
clear_and_print() {
    clear -x
    if [ -n "$1" ]; then
        echo -e "${blue}${1}${reset}"
    fi
}


# Retrieves pod names and stores them in ix_name_array
get_pod_names() {
    clear_and_print "Generating DNS Names.."

    pod_output=$(k3s crictl pods --namespace ix -s Ready | 
                    sed -E 's/[[:space:]]([0-9]*|About)[a-z0-9 ]{5,12}ago[[:space:]]//' |
                    grep -v 'svclb-' |
                    sed '1d')

    if [ -z "$pod_output" ]; then
        echo -e "${red}Error: failed to retrieve pod names${reset}" >&2
        return 1
    fi

    mapfile -t ix_name_array < <(echo "$pod_output" | awk '{print $4}' | sort -u)
}

# Retrieves all port information and stores it in all_ports variable
get_all_ports() {
    if ! all_ports=$(k3s kubectl get service -A); then
        echo -e "${red}Error: failed to retrieve port information${reset}" >&2
        return 1
    fi
}

# Generates the output table with the retrieved pod names and ports
generate_output() {
    clear_and_print ""

    output=""
    headers="${blue}App Name\tDNS Name\tPort${reset}"
    output+="$headers\n"

    for i in "${ix_name_array[@]}"
    do
        full_app_name=$(echo "$pod_output" | grep -E "\s$i\s" | 
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
}

dns() {
    get_pod_names
    if [ ${#ix_name_array[@]} -eq 0 ]; then
        echo -e "${red}There are no applications ready${reset}"
        exit
    fi

    get_all_ports
    generate_output
}
export -f dns
