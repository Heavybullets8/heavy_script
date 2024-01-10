#!/bin/bash


dns_handler() {
    local args=("$@")

    # Check if the help option is in the arguments
    if check_help "${args[@]}"; then
        dns_help
        exit
    fi

    # Check for deprecated options
    if [[ "${args[0]}" == "-a" || "${args[0]}" == "--all" ]]; then
        echo "The option '${args[0]}' is deprecated and will be ignored."
        args=("${args[@]:1}")
    fi

    if [[ ${#args[@]} -eq 0 ]]; then
        dns_verbose
    else
        for app_name in "${args[@]}"; do
            if ! [[ $app_name =~ ^[a-zA-Z]([-a-zA-Z0-9]*[a-zA-Z0-9])?$ ]]; then
                echo "Invalid option or app name: $app_name"
                dns_help
                exit 1
            fi
        done

        dns_verbose "${args[@]}"
    fi
}