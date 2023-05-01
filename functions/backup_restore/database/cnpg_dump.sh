#!/bin/bash


get_current_replica_count() {
    local app_name
    app_name="$1"

    k3s kubectl get deploy -n ix-"$app_name" -o json | jq -r '.items[] | select(.metadata.labels.cnpg != "true" and (.metadata.name | contains("-cnpg-main-") | not)).spec.replicas'
}

dump_database() {
    app="$1"
    # Variables
    output_dir="database_dumps/${app}"
    output_file="${output_dir}/${app}_${timestamp}.sql"

    # Create the output directory if it doesn't exist
    mkdir -p "${output_dir}"

    # Grab the database name from the app's configmap
    db_name=$(midclt call chart.release.get_instance "$app" | jq .config.cnpg.main.database)

    echo "Backing up $app's database: $db_name"
    # Perform pg_dump and save output to a file
    if k3s kubectl exec -n "ix-$app" -c "postgres" "${app}-cnpg-main-1" -- bash -c "pg_dump -Fc -d $db_name" > "$output_file"; then
        return 0
    else
        return 1
    fi
}

# remove databases, keep up to the number of dumps specified, traverse each subdirectory and remove the oldest dumps that exceed the number specified
remove_old_dumps() {
    local main_directory="database_dumps"
    local retention=$1

    if [ -z "$keep_dumps" ]; then
        echo "Usage: remove_old_dumps <number_of_dumps_to_keep>"
        return 1
    fi

    if [ ! -d "$main_directory" ]; then
        echo "Main directory '$main_directory' not found."
        return 1
    fi

    # Traverse each subdirectory
    find "$main_directory" -mindepth 1 -type d | while read -r subdir; do
        # Remove the oldest dumps that exceed the number specified and print their names
        find "$subdir" -type f -name "*.sql" -printf "%T@ %p\n" | sort -rn | awk -v retention="$retention" 'NR>retention {print $2}' | while read -r file; do
            rm "$file"
        done
    done
}

backup_cnpg_databases(){
    retention=$1
    declare cnpg_apps=()
    declare timestamp
    timestamp=$(date '+%Y_%m_%d_%H_%M_%S')
    
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
        
        if dump_database "$app"; then
            echo "Successfully backed up $app's database."
        else
            echo "Failed to back up $app's database."
        fi

        # Scale the resources back to the original replica count
        if [[ $original_replicas -ne 0 ]]; then
            scale_resources "$app" 300 "$original_replicas" > /dev/null 2>&1
        fi
        
    done

    remove_old_dumps "$retention"
}
