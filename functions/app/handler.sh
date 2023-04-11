#!/bin/bash


app_handler() {
    local args=("$@")

    mapfile -t args < <(remove_no_config_args "${args[@]}")

    case "${args[0]}" in
        -s|--start)
            start_app_prompt
            ;;
        -x|--stop)
            stop_app_prompt
            ;;
        -r|--restart)
            restart_app_prompt
            ;;
        -d|--delete)
            delete_app_prompt
            ;;
        -h|--help)
            app_help
            ;;
        *)
            echo "Unknown app action: ${args[0]}"
            app_help
            exit 1
            ;;
    esac
}
