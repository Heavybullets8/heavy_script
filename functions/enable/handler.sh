#!/bin/bash


enable_handler() {
    local args=("$@")

    case "${args[0]}" in
        --api)
            enable_kube_api
            ;;
        --apt)
            toggle_apt "enable"
            ;;
        --disable-apt)
            toggle_apt "disable"
            ;;
        --helm)
            enable_helm
            ;;
        -h|--help)
            enable_help
            ;;
        *)
            echo "Unknown feature: $1"
            enable_help
            ;;
    esac
}