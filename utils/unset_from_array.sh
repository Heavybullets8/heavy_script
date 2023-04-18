#!/bin/bash

remove_self_update_args() {
    local input_args=("$@")
    local output_args=()

    # Set a flag to indicate whether self-update argument is found
    local self_update_found=false

    for arg in "${input_args[@]}"; do
        if [[ "$arg" =~ ^(--)?self-update$ || "$arg" == "-U" ]]; then
            self_update_found=true
        else
            output_args+=("$arg")
        fi
    done

    printf "%s\n" "${output_args[@]}"

    # Return 0 if self-update argument is found, 1 otherwise
    if $self_update_found; then
        return 0
    else
        return 1
    fi
}


remove_no_self_update_args() {
    local input_args=("$@")
    local output_args=()

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

    for arg in "${input_args[@]}"; do
        if [[ "$arg" == "--no-config" ]]; then
            no_config=true
        else
            output_args+=("$arg")
        fi
    done

    printf "%s\n" "${output_args[@]}"
}
