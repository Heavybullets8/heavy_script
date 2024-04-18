#!/bin/bash


get_current_replica_counts() {
    # The following command returns a map where the keys are deployment names and the values are replica counts
    k3s kubectl get deploy -n ix-"$app_name" -o json | jq -r '[.items[] | select(.metadata.labels.cnpg != "true" and (.metadata.name | contains("-cnpg-main-") | not)) | {(.metadata.name): .spec.replicas}] | add'
}

wait_for_pods_to_stop() {
    local timeout deployment_name
    timeout="$1"
    deployment_name="$2"

    SECONDS=0
    while true; do
        # If a specific deployment is provided, check only its pods
        if ! k3s kubectl get pods -n ix-"$app_name" \
                --field-selector=status.phase!=Succeeded,status.phase!=Failed -o=name \
                | grep -vE -- '-[[:digit:]]$' \
                | rev | cut -d- -f3- | rev \
                | grep -vE -- "-cnpg$|-cnpg-" \
                | grep -qE -- "$deployment_name$"; then
            break
        fi
        if [[ "$SECONDS" -gt $timeout ]]; then
            return 1
        fi
        sleep 1
    done
}

scale_deployments() {
    local timeout replicas deployment_name
    timeout="$1"
    replicas="${2:-$(pull_replicas "$app_name")}"
    deployment_name="$3"

    # Specific deployment passed, scale only this deployment
    if ! k3s kubectl scale deployments/"$deployment_name" -n ix-"$app_name" --replicas="$replicas"; then
        failed_message+=("\n$app_name\nFailed to scale $deployment_name")
        return 1
    fi

    if [[ $replicas -eq 0 ]]; then
        if ! wait_for_pods_to_stop "$timeout" "$deployment_name"; then 
            failed_message+=("\n$app_name\nFailed to wait for $deployment_name to stop")
            return 1
        fi
    fi
}

dump_database() {
    output_dir="$1/${app_name}"
    output_file="${output_dir}/${app_name}_${timestamp}.sql.gz"
 
    cnpg_pod=$(k3s kubectl get pods -n "ix-$app_name" --no-headers -o custom-columns=":metadata.name" -l role=primary | head -n 1)

    if [[ -z $cnpg_pod  ]]; then
        failed_message+=("\n$app_name\nFailed to get primary pod")
        return 1
    fi

    # Grab the database name from the app's configmap
    db_name=$(midclt call chart.release.get_instance "$app_name" | jq -r '.config.cnpg.main.database // empty')

    if [[ -z $db_name ]]; then
        failed_message+=("\n$app_name\nFailed to get database name")
        return 1
    fi

    # Create the output directory if it doesn't exist
    mkdir -p "${output_dir}"

    # Perform pg_dump and save output to a file, then compress it using gzip
    if k3s kubectl exec -n "ix-$app_name" -c "postgres" "${cnpg_pod}" -- bash -c "pg_dump -Fc -d $db_name" | gzip > "$output_file"; then
        return 0
    else
        failed_message+=("\n$app_name\nFailed to dump database")
        return 1
    fi
}

# remove databases, keep up to the number of dumps specified, traverse each subdirectory and remove the oldest dumps that exceed the number specified
remove_old_dumps() {
    local main_directory="$1"
    local retention="$2"

    # Traverse each subdirectory
    find "$main_directory" -mindepth 1 -type d | while IFS= read -r subdir; do
        # Remove the oldest dumps that exceed the number specified and print their names
        find "$subdir" -type f -name "*.sql.gz" -printf "%T@ %p\n" | sort -rn | tail -n +$((retention + 1)) | cut -d' ' -f2- | while IFS= read -r file; do
            rm "$file"
        done
    done
}

display_app_sizes() {
    local app_name
    # Initialize an empty string for the output
    output=""

    # Add header lines to the output string
    headers="App Name\tTotal Size"
    output+="$headers\n"

    # Read the output of the du command and append it to the output string
    while IFS= read -r line; do
        app_name=$(echo "$line" | awk '{print $1}')
        dir_size=$(echo "$line" | awk '{print $2}')

        # Check if the folder contains files ending in .sql.gz, only one folder deep
        if find "${dump_folder}/${app_name}" -maxdepth 1 -type f -name "*.sql.gz" | grep -q .; then
            output+="${app_name}\t${dir_size}\n"
        fi
    done < <(du -sh --apparent-size "${dump_folder}"/* | awk -F "${dump_folder}/" '{print $2 "\t" $1}')

    # Format the combined output using column -t and return it
    echo -e "$output" | column -t -s $'\t'
}

db_dump_get_app_status() {
    # Get application names from deployments
    mapfile -t cnpg_apps < <(k3s kubectl get cluster -A --ignore-not-found | grep -E '^(ix-.*\s).*-cnpg-main-' | awk '{gsub(/^ix-/, "", $1); print $1}' | sort -u 2>/dev/null)

    # Store the output of the `cli` command into a variable
    chart_release_output=$(cli -m csv -c 'app chart_release query name,status' | tr -d " \t\r" | tail -n +2)

    declare -a app_status_lines

    # For each app, grep its line from the `cli` command output and add it to the array
    for app_name in "${cnpg_apps[@]}"; do
        app_status_line=$(echo "$chart_release_output" | grep "^$app_name,")
        app_status_lines+=("$app_status_line")
    done

    for line in "${app_status_lines[@]}"; do
        echo "$line"
    done
}

wait_for_postgres_pod() {
    for ((i = 1; i <= 30; i++)); do
        # Get the name of the primary pod
        primary_pod=$(k3s kubectl get pods -n "ix-$app_name" --no-headers -o custom-columns=":metadata.name" -l role=primary | head -n 1 2>/dev/null)
        
        if [[ -z "$primary_pod" ]]; then
            sleep 5
            continue
        fi

        # Get the status of the primary pod
        pod_status=$(k3s kubectl get pod "$primary_pod" -n "ix-$app_name" -o jsonpath="{.status.phase}" 2>/dev/null)

        if [[ "$pod_status" == "Running" ]]; then
            return 0
        else
            sleep 5
        fi
    done
    failed_message+=("\n$app_name\nFailed to wait for postgres pod")
    return 1
}

wait_until_active() {
    timeout=500
    SECONDS=0

    while [[ $(cli -m csv -c 'app chart_release query name,status' | tr -d " \t\r" | grep "^$app_name," | awk -F ',' '{print $2}')  !=  "ACTIVE" ]]
    do
        if [[ "$SECONDS" -ge "$timeout" ]]; then
            failed_message+=("Failed to wait for app to become active")
            return 1
        fi
        sleep 5
    done
    return 0
}

backup_cnpg_databases() {
    local retention=$1
    local timestamp=$2
    local dump_folder=$3
    local stop_before_dump=()
    failed_message=()
    app_name=""
    app_status=""

    mapfile -t app_status_lines < <(db_dump_get_app_status)


    # Get the stop_before_dump value from config.ini
    temp="${DATABASES__databases__stop_before_dump:-}"
    # Split comma-separated values into an array
    IFS=',' read -ra stop_before_dump <<< "$temp"
    unset temp

    if [[ ${#app_status_lines[@]} -eq 0 ]]; then
        return 0
    fi
    
    echo_backup+=("--CNPG Database Backups--")

    for app in "${app_status_lines[@]}"; do
        scale_deployments_bool=false
        IFS=',' read -r app_name app_status <<< "$app"

        if printf '%s\0' "${stop_before_dump[@]}" | grep -iFxqz "${app_name}"; then
            scale_deployments_bool=true
        fi

        # Start the app if it is stopped
        if [[ $app_status == "STOPPED" ]]; then
            if ! start_app "$app_name"; then
                failed_message+=("\n$app_name\nFailed to start")
                continue
            fi
            if ! wait_for_postgres_pod; then
                failed_message+=("\n$app_name\nPostgres pod did not come up")
                continue
            fi
        fi

        # Scale down all non cnpg deployments in the app to 0
        if [[ $scale_deployments_bool == true ]]; then
            declare -A original_replicas=()
            mapfile -t replica_lines < <(get_current_replica_counts | jq -r 'to_entries | .[] | "\(.key)=\(.value)"')
            for line in "${replica_lines[@]}"; do
                IFS='=' read -r key value <<< "$line"
                original_replicas["$key"]=$value
            done

            local scale_failure=false
            # Scale down all deployments in the app to 0
            for deployment in "${!original_replicas[@]}"; do
                if [[ ${original_replicas[$deployment]} -ne 0 ]] && ! scale_deployments 300 0 "$deployment" > /dev/null 2>&1; then
                    scale_failure=true
                    break
                fi
            done
            if [[ $scale_failure == true ]]; then
                continue
            fi
        fi
                                         
        # Dump the database
        if ! dump_database "$dump_folder"; then
            continue
        fi

        # Stop the app if it was stopped
        if [[ $app_status == "STOPPED" ]]; then
            if wait_until_active; then 
                if stop_app "direct" "$app_name"; then
                    failed_message+=("\n$app_name\nFailed to stop")
                fi
            fi
            continue
        fi

        if [[ $scale_deployments_bool == true ]]; then
            # Scale up all deployments in the app to their original replica counts
            for deployment in "${!original_replicas[@]}"; do
                if [[ ${original_replicas[$deployment]} -ne 0 ]] && ! scale_deployments 300 "${original_replicas[$deployment]}" "$deployment" > /dev/null 2>&1; then
                    failed_message+=("\n$app_name\nFailed to scale up $deployment")
                    break
                fi
            done
        fi
    done

    if [[ ${#failed_message[@]} -gt 0 ]]; then
        echo -e "\n--Failed Database Dumps--"
        for message in "${failed_message[@]}"; do
            echo -e "$message"
        done
        echo
    fi

    remove_old_dumps "$dump_folder" "$retention"
    echo_backup+=("$(display_app_sizes "$dump_folder")")
}