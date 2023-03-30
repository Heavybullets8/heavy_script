#!/bin/bash


pod_handler() {
    local args=("$@")

    mapfile -t args < <(remove_no_config_args "${args[@]}")

    case "${args[0]}" in
        -l | --logs)
            # Call the function to display container logs
            container_shell_or_logs "logs"
            ;;
        -s | --shell)
            # Call the function to open a shell for the container
            container_shell_or_logs "shell"
            ;;
        -h | --help)
            # Call the function to display help for the pod command
            pod_help
            ;;
        *)
            echo "Invalid option: ${args[0]}"
            echo "Usage: heavyscript pod [-l | --logs | -s | --shell | -h | --help]"
            exit 1
            ;;
    esac
}
