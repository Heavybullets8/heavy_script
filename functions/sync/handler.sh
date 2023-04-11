#!/bin/bash


sync_handler() {
    if [[ "$#" -eq 0 ]]; then
        sync_catalog "direct"
        return
    fi

    while [[ "$#" -gt 0 ]]; do
        case $1 in
            --no-config)
                shift
                ;;
            -h | --help)
                # Call the function to display help for the pvc command
                sync_help
                ;;
            *)
                echo "Invalid option: $1"
                sync_help
                exit 1
                ;;
        esac
        shift
    done
}