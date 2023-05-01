#!/bin/bash
# Create a backup folder
backup_folder="./dumps/"
mkdir -p "$backup_folder"

# Function to get PostgreSQL pod namespaces
get_namespaces() {
  if [ -z "$1" ]; then
    k3s kubectl get pods -A | grep postgres | awk '{print $1}'
  else
    echo "ix-$1"
  fi
}

# Function to get non-cnpg deployments
get_non_cnpg_deployments() {
  local ns="$1"
  k3s kubectl get deploy -n "$ns" | grep -vE '\-cnpg\-|NAME' | awk '{print $1}'
}

# Function to scale deployment
scale_deployment() {
  local ns="$1"
  local app="$2"
  local replicas="$3"
  k3s kubectl scale deploy "$app" -n "$ns" --replicas="$replicas"
}

# Function to wait for deployments to scale down
wait_for_scale_down() {
  local ns="$1"
  local deploy="$2"
  while true; do
    local ready_replicas
    ready_replicas=$(k3s kubectl get deploy "$deploy" -n "$ns" -o jsonpath='{.status.readyReplicas}')
    if [ -z "$ready_replicas" ] || [ "$ready_replicas" == "0" ]; then
      break
    else
      sleep 1
    fi
  done
}


# Get the optional application name from the command line argument
app_name="$1"

# Main loop to process each namespace
for ns in $(get_namespaces "$app_name"); do
    # Extract application name
    app=$(echo "$ns" | sed 's/^ix-//')

    echo "Creating database backup for $app."

    file="${app}.sql"

    # Get non-cnpg deployments
    non_cnpg_deployments=$(get_non_cnpg_deployments "$ns")

    # Scale down non-cnpg deployments to avoid inconsistencies in DB
    for deploy in $non_cnpg_deployments; do
        scale_deployment "$ns" "$deploy" 0
        wait_for_scale_down "$ns" "$deploy"
    done

    # Backup database
    temp_dir=$(mktemp -d)
    k3s kubectl exec -n "$ns" -c "postgres" "${app}-cnpg-main-2" -- bash -c "PGPASSWORD=$POSTGRES_PASSWORD pg_dump -Fc -U $POSTGRES_USER -d $POSTGRES_DB -f /backup/$file"
    k3s kubectl cp -n "$ns" -c "postgres" "${app}-cnpg-main-2:/backup/$file" "$temp_dir/$file"
    mv "$temp_dir/$file" "$backup_folder$file"
    rm -r "$temp_dir"

    # Scale non-cnpg deployments back up
    for deploy in $non_cnpg_deployments; do
        scale_deployment "$ns" "$deploy" 1
    done

    if [ ! -f "$backup_folder$file" ]; then
        >&2 echo "$backup_folder$file does not exist."
        exit 1
    fi

    echo "File $file created."
done

exit 0