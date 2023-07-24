#!/bin/bash

generate_app_logs_prompt(){
    if [[ -z $1 ]]; then

        # Get app name from user input
        read -p "Enter app name: " APP_NAME
     
    else
        APP_NAME="$1"
    fi  
    # Prepend 'ix-' to app name
    APP_NAME="ix-$APP_NAME"

    # Create logs directory with timestamp
    TIMESTAMP=$(date +%Y-%m-%d_%H-%M-%S)
    LOGS_DIR="$APP_NAME-logs-$TIMESTAMP"
    mkdir -p "$LOGS_DIR"

    # Get list of pods in app and write to log file
    LIST_FILE="$LOGS_DIR/list_of_pods.log"
    k3s kubectl get pods -n $APP_NAME -o jsonpath='{.items[*].metadata.name}' > "$LIST_FILE"

    # Loop through each pod and get its logs
    for POD in $(cat "$LIST_FILE")
    do
    echo "Getting logs for pod $POD..."
    LOG_FILE="$LOGS_DIR/$POD.log"
    k3s kubectl logs -n $APP_NAME $POD > "$LOG_FILE" 2>&1 || echo "Error getting logs for pod $POD" >> "$LOG_FILE"
    done
}
