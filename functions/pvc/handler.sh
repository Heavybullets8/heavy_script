#!/bin/bash


pvc_handler() {
    if [[ "$#" -eq 0 ]]; then
        mount_prompt
        exit
    fi

    while [[ "$#" -gt 0 ]]; do
        case $1 in
            --no-config)
                shift
                ;;
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
                echo "Invalid option: $1"
                pvc_help
                ;;
        esac
        shift
    done
}
