#!/bin/bash


dns(){
clear -x
echo "Generating DNS Names.."
#ignored dependency pods, may need to add more in the future.
dep_ignore="\-cronjob\-|^kube-system|\ssvclb|NAME|\-memcached\-.[^custom\-app]|\-postgresql\-.[^custom\-app]|\-redis\-.[^custom\-app]|\-mariadb\-.[^custom\-app]|\-promtail\-.[^custom\-app]"

# Pulling pod names
mapfile -t main < <(k3s kubectl get pods -A | grep -Ev "$dep_ignore" | sort)

# Pulling all ports
all_ports=$(k3s kubectl get service -A)

clear -x
count=0
for i in "${main[@]}"
do
    [[ count -le 0 ]] && echo -e "\n" && ((count++))
    appName=$(echo "$i" | awk '{print $2}' | sed 's/-[^-]*-[^-]*$//' | sed 's/-0//')
    ixName=$(echo "$i" | awk '{print $1}')
    port=$(echo "$all_ports" | grep -E "\s$appName\s" | awk '{print $6}' | grep -Eo "^[[:digit:]]+{1}")
    echo -e "$appName.$ixName.svc.cluster.local $port"
done | uniq | nl -b t | sed 's/\s\s\s$/- -------- ----/' | column -t -R 1 -N "#,DNS_Name,Port" -L
}
export -f dns