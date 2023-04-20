#!/bin/bash

remove_self_update_args() {
    local input_args=("$@")
    local output_args=()

    for arg in "${input_args[@]}"; do
        if ! [[ "$arg" =~ ^(--)?self-update$ || "$arg" == "-U" ]]; then
            output_args+=("$arg")
        fi
    done

    printf "%s\n" "${output_args[@]}"
}


remove_no_self_update_args() {
    local input_args=("$@")
    local output_args=()

    for arg in "${input_args[@]}"; do
        if ! [[ "$arg" == "--no-self-update" ]]; then
            output_args+=("$arg")
        fi
    done

    printf "%s\n" "${output_args[@]}"
}


remove_force_update_args() {
    local input_args=("$@")
    local output_args=()

    for arg in "${input_args[@]}"; do
        if ! [[ "$arg" == "--major" ]]; then
            output_args+=("$arg")
        fi
    done

    printf "%s\n" "${output_args[@]}"
}

# Function to remove --no-config from the arguments and return exit code
remove_no_config_args() {
    local output_args=()
    local found=1

    for arg in "${args[@]}"; do
        if [[ "$arg" == "--no-config" ]]; then
            found=0
        else
            output_args+=("$arg")
        fi
    done

    args=("${output_args[@]}")
    return $found
}
