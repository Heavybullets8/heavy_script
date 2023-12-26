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
            awk -F ',' '{print $2}' | \
            tr -d " \t\r"
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
            echo "Operators are not meant to be stopped"
            return 1
            ;;
    esac
}

stop_app() {
    # Return 1 if cli command outright fails
    # Return 2 if timeout is reached
    # Return 3 if app is an operator 

    local stop_type app_name timeout status
    stop_type="$1"
    app_name="$2"
    timeout="250"

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

    # If the status is STOPPED and the output does not contain a line with the pattern "${app_name},stopAll"
    if [[ "$status" == "STOPPED" ]] && ! echo "$output" | grep -q "${app_name},stopAll"; then
        return 0 # Exit the function
    fi

    # Check if the output contains the desired namespace and "cnpg" or "operator"
    if echo "$output" | grep -q "${app_name},operator"; then
        return 3
    elif echo "$output" | grep -q "${app_name},stopAll-*"; then
        timeout "${timeout}s" cli -c "app chart_release update chart_release=\"$app_name\" values={\"global\": {\"stopAll\": true}}" > /dev/null 2>&1
        handle_timeout $?
    else
        timeout "${timeout}s" cli -c 'app chart_release scale release_name='\""$app_name"\"\ 'scale_options={"replica_count": '"0}" > /dev/null 2>&1
        handle_timeout $?
    fi
}