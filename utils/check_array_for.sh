#!/bin/bash


# Function to check if --no-config is in the arguments
check_no_config() {
    local args=("$@")
    for arg in "${args[@]}"; do
        if [[ "$arg" == "--no-config" ]]; then
            return 0  # --no-config found
        fi
    done
    return 1  # --no-config not found
}


# Function to check if --help is in the arguments
check_help() {
    local args=("$@")
    if [[ "${args[*]}" =~ ^(--help|-h)$ ]]; then
        return 0  # --help found
    fi
    return 1  # --help not found
}