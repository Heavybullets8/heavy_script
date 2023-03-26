#!/bin/bash


check_filterd_apps(){
    declare -A unique_namespaces

    # Get all pods with the Ready status using k3s crictl command and output in JSON format
    ready_pods=$(k3s crictl pods --namespace ix --output json -s Ready)

    # Get all pod metadata in a single kubectl call with JSON output
    all_pods=$(k3s kubectl get pods --all-namespaces -o json)

    # Filter out the namespace of pods that don't have 'svclb-' in their name
    pod_namespaces=$(echo "$ready_pods" |
                    jq -r '.items[] | select(.metadata.name | startswith("svclb-") | not) | .metadata.namespace')

    # Get only the necessary fields (namespace, name, labels) from all pods
    all_pods_filtered=$(echo "$all_pods" | jq '.items[] | {namespace: .metadata.namespace, name: .metadata.name, labels: .metadata.labels}')

    process_namespace() {
        local namespace namespace_pods pod_names labels managed_by postgresql reason
        namespace="$1"

        # Filter pods in the current namespace
        namespace_pods=$(echo "$all_pods_filtered" | jq --arg namespace "$namespace" 'select(.namespace == $namespace)')

        # Get the pod names in the current namespace
        pod_names=$(echo "$namespace_pods" | jq -r '.name')

        while IFS= read -r pod_name; do

            labels=$(echo "$namespace_pods" | jq -r --arg pod_name "$pod_name" 'select(.name == $pod_name) | .labels')
            managed_by=$(echo "$labels" | jq -r '."app.kubernetes.io/managed-by"')
            postgresql=$(echo "$labels" | jq -r '.postgresql')

            reason=""
            if [[ "$managed_by" == *"-operator"* ]]; then
                reason="operator"
            elif [[ "$postgresql" == *"-cnpg-main"* ]]; then
                reason="cnpg"
            fi

            if [ -n "$reason" ]; then
                echo "$namespace,$reason"
                break
            fi
        done <<< "$pod_names"
    }

    # Loop through the pod namespaces
    temp_file=$(mktemp)
    trap 'rm -f "$temp_file"' EXIT
    while IFS= read -r namespace; do
        # Check if the namespace is already processed
        if [[ -z "${unique_namespaces[$namespace]}" ]]; then
            process_namespace "$namespace" >> "$temp_file" &
        fi
    done <<< "$pod_namespaces"

    # Wait for all background jobs to finish
    wait

    # Read the temporary file and store the results in unique_namespaces
    while IFS= read -r line; do
        IFS=',' read -ra fields <<< "$line"
        unique_namespaces["${fields[0]}"]="${fields[1]}"
    done < "$temp_file"

    # Print the unique namespaces with reasons
    for namespace in "${!unique_namespaces[@]}"; do
        echo "$namespace,${unique_namespaces[$namespace]}"
    done
}
