#!/bin/bash


get_current_replica_counts() {
    local app_name
    app_name="$1"
    # The following command returns a map where the keys are deployment names and the values are replica counts
    k3s kubectl get deploy -n ix-"$app_name" -o json | jq -r '[.items[] | select(.metadata.labels.cnpg != "true" and (.metadata.name | contains("-cnpg-main-") | not)) | {(.metadata.name): .spec.replicas}] | add'
}

wait_for_pods_to_stop() {
    local app_name timeout deployment_name
    app_name="$1"
    timeout="$2"
    deployment_name="$3"

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
    local app_name timeout replicas deployment_name
    app_name="$1"
    timeout="$2"
    replicas="${3:-$(pull_replicas "$app_name")}"
    deployment_name="$4"

    # Specific deployment passed, scale only this deployment
    k3s kubectl scale deployments/"$deployment_name" -n ix-"$app_name" --replicas="$replicas" || return 1

    if [[ $replicas -eq 0 ]]; then
        wait_for_pods_to_stop "$app_name" "$timeout" "$deployment_name" && return 0 || return 1
    fi
}

dump_database() {
    app="$1"
    output_dir="$2/${app}"
    output_file="${output_dir}/${app}_${timestamp}.sql.gz"

    cnpg_pod=$(k3s kubectl get pods -n "ix-$app" --no-headers -o custom-columns=":metadata.name" | grep -E -- "-cnpg-main-1$")

    if [[ -z $cnpg_pod ]]; then
        echo_backup+=("Failed to get cnpg pod for $app.")
        return 1
    fi

    # Grab the database name from the app's configmap
    db_name=$(midclt call chart.release.get_instance "$app" | jq .config.cnpg.main.database)

    if [[ -z $db_name ]]; then
        echo_backup+=("Failed to get database name for $app.")
        return 1
    fi

    # Create the output directory if it doesn't exist
    mkdir -p "${output_dir}"

    # Perform pg_dump and save output to a file, then compress it using gzip
    if k3s kubectl exec -n "ix-$app" -c "postgres" "${cnpg_pod}" -- bash -c "pg_dump -Fc -d $db_name" | gzip > "$output_file"; then
        return 0
    else
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
    local dump_folder="$1"

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
    mapfile -t cnpg_apps < <(k3s kubectl get deployments --all-namespaces | grep -E '^(ix-.*\s).*-cnpg-main-' | awk '{gsub(/^ix-/, "", $1); print $1}')

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
    app_name=$1

    # shellcheck disable=SC2034
    for i in {1..30}; do
        pod_status=$(k3s kubectl get pods "${app_name}-cnpg-main-1" -n "ix-${app_name}" -o jsonpath="{.status.phase}" 2>/dev/null)

        if [[ "$pod_status" == "Running" ]]; then
            return 0
        else
            sleep 5
        fi
    done
    return 1
}

get_redeploy_job_ids(){
    local app_name=$1
    midclt call core.get_jobs | jq -r --arg app_name "$app_name" \
        '.[] | select( .time_finished == null and .state == "RUNNING" and (.arguments[0] == $app_name) and (.method == "chart.release.redeploy" or .method == "chart.release.redeploy_internal")) | .id'
}

wait_for_redeploy_jobs(){
    local app_name=$1
    local sleep_duration=10
    local timeout=500
    local elapsed_time=0

    while true; do
        job_ids=$(get_redeploy_job_ids "$app_name")

        if [[ -z "$job_ids" ]]; then
            break
        else
            sleep "$sleep_duration"
            elapsed_time=$((elapsed_time + sleep_duration))

            # Check for timeout
            if [[ "$elapsed_time" -ge "$timeout" ]]; then
                while IFS= read -r job_id; do
                    midclt call core.job_abort "$job_id" > /dev/null 2>&1
                done <<< "$job_ids"
                return 1
            fi
        fi
    done
}

backup_cnpg_databases() {
    local retention=$1
    local timestamp=$2
    local dump_folder=$3
    local stop_before_dump=()

    mapfile -t app_status_lines < <(db_dump_get_app_status)


    # Get the stop_before_dump value from config.ini
    temp="${DATABASES__databases__stop_before_dump:-}"
    # Split comma-separated values into an array
    IFS=',' read -ra stop_before_dump <<< "$temp"
    unset temp

    if [[ ${#app_status_lines[@]} -eq 0 ]]; then
        return
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
            start_app "$app_name"
            wait_for_postgres_pod "$app_name"
        fi

        declare -A original_replicas=()
        mapfile -t replica_lines < <(get_current_replica_counts "$app_name" | jq -r 'to_entries | .[] | "\(.key)=\(.value)"')
        for line in "${replica_lines[@]}"; do
            IFS='=' read -r key value <<< "$line"
            original_replicas["$key"]=$value
        done

        if [[ $scale_deployments_bool == true ]]; then
            # Scale down all deployments in the app to 0
            for deployment in "${!original_replicas[@]}"; do
                if [[ ${original_replicas[$deployment]} -ne 0 ]] && ! scale_deployments "$app_name" 300 0 "$deployment" > /dev/null 2>&1; then
                    echo_backup+=("Failed to scale down $app_name's $deployment deployment.")
                    return
                fi
            done
        fi

        # Dump the database
        if ! dump_database "$app_name" "$dump_folder"; then
            echo_backup+=("Failed to back up $app_name's database.")
            return
        fi

        # Stop the app if it was stopped
        if [[ $app_status == "STOPPED" ]]; then
            wait_for_redeploy_jobs "$app_name"
            stop_app "direct" "$app_name"
            break
        fi


        if [[ $scale_deployments_bool == true ]]; then
            # Scale up all deployments in the app to their original replica counts
            for deployment in "${!original_replicas[@]}"; do
                if [[ ${original_replicas[$deployment]} -ne 0 ]] && ! scale_deployments "$app_name" 300 "${original_replicas[$deployment]}" "$deployment" > /dev/null 2>&1; then
                    echo_backup+=("Failed to scale up $app_name's $deployment deployment.")
                    return
                fi
            done
        fi
    done

    remove_old_dumps "$dump_folder" "$retention"
    echo_backup+=("$(display_app_sizes "$dump_folder")")
}