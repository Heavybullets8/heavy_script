#!/bin/bash


dns_verbose(){
    app_name="$1"

    # Get all ix-namespaces and services
    if [[ -z $app_name ]]; then
        services=$(k3s kubectl get service -A | grep ^"ix" | sort -u)
    else
        services=$(k3s kubectl get service -n "ix-$app_name" | sort -u)
    fi

    services=$(k3s kubectl get service -A | grep ^"ix" | sort -u)

    output=""

    # Iterate through each namespace and service
    while IFS=$'\n' read -r service; do
        namespace=$(echo "$service" | awk '{print $1}')
        svc_name=$(echo "$service" | awk '{print $2}')
        ports=$(echo "$service" | awk '{print $6}')

        # Print namespace if it's different from the previous one
        if [ "$namespace" != "$prev_namespace" ]; then
            output+="\n"
            output+="${blue}${namespace}${reset}\n"
        fi
        dns_name=""
        dns_name+="$svc_name"
        dns_name+=".$namespace"
        dns_name+=".svc.cluster.local"

        # Print pod and relevant ports
        output+="${dns_name}\t${ports}\n"

        # Set previous namespace for comparison
        prev_namespace="$namespace"
        # Add an extra newline after each namespace

    done <<< "$services"

    # Format the output using column
    echo -e "$output" | sed '1d;$d' | column -L -t -s $'\t'
}