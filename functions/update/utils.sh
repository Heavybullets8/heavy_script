#!/bin/bash


update_stop_handler(){
    local message="$1"

    if [[ "$verbose" == true ]]; then
        echo_array+=("$message")
    fi
    stop_app "update" "$app_name" "${timeout:-100}"
    result=$(handle_stop_code "$?")
    if [[ $? -eq 1 ]]; then
        echo_array+=("$result")
    else
        echo_array+=("$result")
    fi
    return
}