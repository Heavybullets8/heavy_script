#!/bin/bash


app_handler() {
    local args=("$@")

    case "${args[0]}" in
        -s|--start)
            start_app_prompt "${args[@]:1}"
            ;;
        -x|--stop)
            stop_app_prompt "${args[@]:1}"
            ;;
        -r|--restart)
            restart_app_prompt "${args[@]:1}"
            ;;
        -d|--delete)
            delete_app_prompt "${args[@]:1}"
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
