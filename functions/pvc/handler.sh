#!/bin/bash


pvc_handler() {
    local args=("$@")

    # If no arguments are provided, call the mount_prompt function
    if [ -z "${args[*]}" ]; then
        mount_prompt
        return
    fi

    case "${args[0]}" in
        -m | --mount)
            # Call the function to mount the app
            mount_app_func "${args[@]:1}"
            ;;
        -u | --unmount) 
            # Call the function to unmount the app
            unmount_app_func "${args[@]:1}"
            ;;
        -h | --help)
            # Call the function to display help for the pvc command
            pvc_help
            ;;
        *)
            echo "Invalid option: ${args[0]}"
            pvc_help
            exit 1
            ;;
    esac
}
