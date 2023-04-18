#!/bin/bash


# Function to check if --no-config is in the arguments
check_no_config() {
    local arg
    for arg in "$@"; do
        if [[ "$arg" == "--no-config" ]]; then
            return 0  # found
        fi
    done
    return 1  # not found
}

check_self_update_args() {
    local arg
    for arg in "$@"; do
        if [[ "$arg" =~ ^(--)?self-update$ || "$arg" == "-U" ]]; then
            return 0  # found
        fi
    done
    return 1  # not found
}

check_no_self_update_args() {
    local arg
    for arg in "$@"; do
        if [[ "$arg" == "--no-self-update" ]]; then
            return 0  # found
        fi
    done
    return 1  # not found
}

check_force_update_args() {
    local arg
    for arg in "$@"; do
        if [[ "$arg" == "--major" ]]; then
            return 0  # found
        fi
    done
    return 1  # not found
}

# Function to check if --help is in the arguments
check_help() {
    local args=("$@")
    if [[ "${args[*]}" =~ ^(--help|-h)$ ]]; then
        return 0  # --help found
    fi
    return 1  # --help not found
}