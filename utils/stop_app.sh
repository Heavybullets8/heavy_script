#!/bin/bash

get_app_status() {
    local app_name stop_type
    app_name="$1"
    stop_type="$2"

    if [[ "$stop_type" == "update" ]]; then
        grep "^$app_name," all_app_status | awk -F ',' '{print $2}'
    else
        cli -m csv -c 'app chart_release query name,status' | \
            grep -- "^$app_name," | \
            awk -F ',' '{print $2}'
    fi
}

handle_stop_code() {
    local stop_code
    stop_code="$1"

    case "$stop_code" in
        0)
            echo "Stopped"
            return 0
            ;;
        1)
            echo -e "Failed to stop\nManual intervention may be required"
            return 1
            ;;
        2)
            echo -e "Timeout reached\nManual intervention may be required"
            return 1
            ;;
        3)
            echo "HeavyScript doesn't have the ability to stop Prometheus"
            return 1
            ;;
    esac
}

stop_app() {
    # Return 1 if cli command outright fails
    # Return 2 if timeout is reached
    # Return 3 if app is a prometheus instance

    local stop_type app_name timeout status
    stop_type="$1"
    app_name="$2"
    timeout="150"

    handle_timeout() {
        local timeout_result=$1
        if [[ $timeout_result -eq 0 ]]; then
            return 0
        elif [[ $timeout_result -eq 124 ]]; then
            return 2
        else
            return 1
        fi
    }

    status=$(get_app_status "$app_name" "$stop_type")
    output=$(check_filtered_apps "$app_name")

    if [[ "$status" == "STOPPED" ]]; then
        return 0
    fi

    # Check if the output contains the desired namespace and "cnpg" or "operator"
    case $output in
        "${app_name},stopAll-on" | "${app_name},stopAll-off")
            timeout "${timeout}s" cli -c "app chart_release update chart_release=\"$app_name\" values={\"global\": {\"stopAll\": true}}" > /dev/null
            handle_timeout $?
            ;;
        "${app_name},operator")
            return 3
            ;;
        *)
            timeout "${timeout}s" cli -c 'app chart_release scale release_name='\""$app_name"\"\ 'scale_options={"replica_count": 0}' > /dev/null
            handle_timeout $?
            ;;
    esac
}