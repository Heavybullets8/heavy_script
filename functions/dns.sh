#!/bin/bash


dns(){
clear -x
echo "Generating DNS Names.."
# Ignore svclb
dep_ignore='svclb-'

# Pulling pod names
k3s crictl pods --namespace ix -s Ready | sed -E 's/[[:space:]]([0-9]*|About)[a-z0-9 ]{5,12}ago[[:space:]]//' | grep -Ev -- "$dep_ignore" | sed '1d'  >> dns_file
mapfile -t ixName < <(< dns_file awk '{print $4}' | sort -u )

# Pulling all ports
all_ports=$(k3s kubectl get service -A)

clear -x
count=0
for i in "${ixName[@]}"
do
    [[ count -le 0 ]] && echo -e "\n" && ((count++))
    appName=$(grep -E "\s$i\s" "dns_file" | awk '{print $3}' | sed 's/-[^-]*-[^-]*$//' | sed 's/-0//' | head -n 1)
    port=$(echo "$all_ports" | grep -E "\s$appName\s" | awk '{print $6}' | grep -Eo "^[[:digit:]]+{1}")
    echo -e "$appName $appName.$i.svc.cluster.local $port"
done | nl -s ") " -b t | sed '0,/\s\s\s/{s/\s\s\s/- ---- -------- ----/}'| column -t -N "#,Name,DNS_Name,Port"
rm dns_file
}
export -f dns