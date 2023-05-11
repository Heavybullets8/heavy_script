#!/bin/bash


prune_handler() {
    local args=("$@")

    case "${args[0]}" in
        -h | --help)
            # Call the function to display help for the pvc command
            prune_help
            ;;
        "")
            prune
            return
            ;;
        *)
            echo "Invalid option: ${args[0]}"
            prune_help
            exit 1
            ;;
    esac
}
