#!/bin/bash


enable_handler() {
    local args=("$@")

    mapfile -t args < <(remove_no_config_args "${args[@]}")

    case "${args[0]}" in
        --api)
            enable_kube_api
            ;;
        --apt)
            enable_apt
            ;;
        --helm)
            enable_helm
            ;;
        --help)
            enable_help
            ;;
        *)
            echo "Unknown feature: $1"
            enable_help
            ;;
    esac
}













