#!/bin/bash


enable_handler() {
    local args=("$@")

    case "${args[0]}" in
        --api)
            manage_kube_api "enable"
            ;;
        --disable-api)
            manage_kube_api "disable"
            ;;
        --apt)
            toggle_apt "enable"
            ;;
        --disable-apt)
            toggle_apt "disable"
            ;;
        --helm)
            enable_helm "enable"
            ;;
        --disable-helm)
            enable_helm "disable"
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