#!/bin/bash


get_current_replica_count() {
    local app_name
    app_name="$1"

    k3s kubectl get deploy -n ix-"$app_name" -o json | jq -r '.items[] | select(.metadata.labels.cnpg != "true" and (.metadata.name | contains("-cnpg-main-") | not)).spec.replicas'
}

dump_database() {
    app="$1"
    output_dir="$2/${app}"
    output_file="${output_dir}/${app}_${timestamp}.sql.gz"

    # Create the output directory if it doesn't exist
    mkdir -p "${output_dir}"

    # Grab the database name from the app's configmap
    db_name=$(midclt call chart.release.get_instance "$app" | jq .config.cnpg.main.database)

    # Perform pg_dump and save output to a file, then compress it using gzip
    if k3s kubectl exec -n "ix-$app" -c "postgres" "${app}-cnpg-main-1" -- bash -c "pg_dump -Fc -d $db_name" | gzip > "$output_file"; then
        return 0
    else
        return 1
    fi
}

# remove databases, keep up to the number of dumps specified, traverse each subdirectory and remove the oldest dumps that exceed the number specified
remove_old_dumps() {
    local main_directory="$1"
    local retention=$2

    # Traverse each subdirectory
    find "$main_directory" -mindepth 1 -type d | while read -r subdir; do
        # Remove the oldest dumps that exceed the number specified and print their names
        find "$subdir" -type f -name "*.sql.gz" -printf "%T@ %p\n" | sort -rn | awk -v retention="$retention" 'NR>retention {print $2}' | while read -r file; do
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

        output+="${app_name}\t${dir_size}\n"
    done < <(du -sh "${dump_folder}"/* | awk -F "${dump_folder}/" '{print $2 "\t" $1}')

    # Format the combined output using column -t and return it
    echo -e "$output" | column -t -s $'\t'
}

backup_cnpg_databases(){
    retention=$1
    timestamp=$2
    dump_folder=$3
    declare cnpg_apps=()
    local failure=false
    
    mapfile -t cnpg_apps < <(k3s kubectl get deployments --all-namespaces | grep -E '^(ix-.*\s).*-cnpg-main-' | awk '{gsub(/^ix-/, "", $1); print $1}')

    if [[ ${#cnpg_apps[@]} -eq 0 ]]; then
        return
    fi

    for app in "${cnpg_apps[@]}"; do
        # Store the current replica count before scaling down
        original_replicas=$(get_current_replica_count "$app")

        if [[ $original_replicas -ne 0 ]]; then
            scale_resources "$app" 300 0 > /dev/null 2>&1
        fi
        
        if ! dump_database "$app" "$dump_folder"; then
            echo_backup+=("Failed to back up $app's database.")
            failure=true
        fi

        # Scale the resources back to the original replica count
        if [[ $original_replicas -ne 0 ]]; then
            scale_resources "$app" 300 "$original_replicas" > /dev/null 2>&1
        fi
        
    done

    if [[ $failure = false ]]; then
        echo_backup+=("Successfully backed up CNPG databases:")
    fi

    remove_old_dumps "$dump_folder" "$retention"

    formatted_output=$(display_app_sizes "$dump_folder")
    echo_backup+=("$formatted_output")
}
