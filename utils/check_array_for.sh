#!/bin/bash


# Function to check if --help is in the arguments
check_help() {
    local args=("$@")
    if [[ "${args[*]}" =~ ^(--help|-h)$ ]]; then
        return 0  # --help found
    fi
    return 1  # --help not found
}