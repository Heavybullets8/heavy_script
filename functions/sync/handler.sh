#!/bin/bash


sync_handler() {
    local args=("$@")

    case "${args[0]}" in
        -h | --help)
            # Call the function to display help for the pvc command
            sync_help
            ;;
        "")
            sync_catalog "direct"
            return
            ;;
        *)
            echo "Invalid option: ${args[0]}"
            sync_help
            exit 1
            ;;
    esac
}
