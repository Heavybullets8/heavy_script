#!/bin/bash

remove_self_update_args() {
    local output_args=()
    local found=1

    for arg in "${args[@]}"; do
        if [[ "$arg" =~ ^(--)?self-update$ || "$arg" == "-U" ]]; then
            found=0
        else
            output_args+=("$arg")
        fi
    done

    args=("${output_args[@]}")
    return $found
}

remove_force_update_args() {
    local output_args=()
    local found=1

    for arg in "${args[@]}"; do
        if [[ "$arg" == "--major" ]]; then
            found=0
        else
            output_args+=("$arg")
        fi
    done

    args=("${output_args[@]}")
    return $found
}

remove_no_self_update_args() {
    local output_args=()
    local found=1

    for arg in "${args[@]}"; do
        if [[ "$arg" == "--no-self-update" ]]; then
            found=0
        else
            output_args+=("$arg")
        fi
    done

    args=("${output_args[@]}")
    return $found
}

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
