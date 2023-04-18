#!/bin/bash

remove_self_update_args() {
    local input_args=("$@")
    local output_args=()
    export self_update=false

    for arg in "${input_args[@]}"; do
        if [[ "$arg" =~ ^(--)?self-update$ || "$arg" == "-U" ]]; then
            self_update=true
        else
            output_args+=("$arg")
        fi
    done

    printf "%s\n" "${output_args[@]}"
}


remove_no_self_update_args() {
    local input_args=("$@")
    local output_args=()
    export no_self_update=false

    for arg in "${input_args[@]}"; do
        if [[ "$arg" == "--no-self-update" ]]; then
            no_self_update=true
        else
            output_args+=("$arg")
        fi
    done

    printf "%s\n" "${output_args[@]}"
}


remove_force_update_args() {
    local input_args=("$@")
    local output_args=()
    export force_update=false

    for arg in "${input_args[@]}"; do
        if [[ "$arg" == "--major" ]]; then
            major_self_update=true
        else
            output_args+=("$arg")   
        fi
    done

    printf "%s\n" "${output_args[@]}"
}


remove_no_config_args() {
    local input_args=("$@")
    local output_args=()
    export no_config=false

    for arg in "${input_args[@]}"; do
        if [[ "$arg" == "--no-config" ]]; then
            no_config=true
        else
            output_args+=("$arg")
        fi
    done

    printf "%s\n" "${output_args[@]}"
}
