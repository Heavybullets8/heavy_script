#!/bin/bash


self_update_handler() {
    local args=("$@")
    local self_update=false
    local no_self_update=false
    local include_major=false

    for arg in "${args[@]}"; do
        if [[ "$arg" =~ ^(--)?self-update$ || "$arg" == "-U" ]]; then
            self_update=true
        elif [[ "$arg" == "--no-self-update" ]]; then
            no_self_update=true
            break
        elif [[ "$arg" == "--major" ]]; then
            include_major=true
        fi
    done


    # Check if second element is a --help/-h argument and self_update is not equal to true
    if [[ "${args[1]}" =~ ^(--help|-h)$ ]] && [[ "${self_update}" == "false" ]]; then
        self_update_help
        exit
    fi


    if $self_update && ! $no_self_update; then
        self_update 
    fi


    # Clean args



}
export -f self_update_handler
