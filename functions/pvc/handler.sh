#!/bin/bash


pvc_handler() {
    local args=("$@")

    mapfile -t args < <(remove_no_config_args "${args[@]}")

    # If no arguments are provided, call the mount_prompt function
    if [ -z "${args[*]}" ]; then
        mount_prompt
        return
    fi

    case "${args[0]}" in
        -m | --mount)
            # Call the function to mount the app
            mount_app_func
            ;;
        -u | --unmount)
            # Call the function to unmount the app
            unmount_app_func
            ;;
        -h | --help)
            # Call the function to display help for the pvc command
            pvc_help
            ;;
        *)
            echo "Invalid option: ${args[0]}"
            echo "Usage: heavyscript pvc [-m | --mount | -u | --unmount | -h | --help]"
            exit 1
            ;;
    esac
}
