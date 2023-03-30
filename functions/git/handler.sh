#!/bin/bash


git_handler() {
    local args=("$@")

    mapfile -t args < <(remove_no_config_args "${args[@]}")

    case "${args[0]}" in
        -b|--branch)
            # Call the function to choose a branch
            choose_branch
            ;;
        -g|--global)
            # Call the function to add the script to the global path
            add_script_to_global_path
            ;;
        -h|--help)
            # Call the function to display help for the git command
            git_help
            ;;
        *)
            echo "Invalid option: ${args[0]}"
            echo "Usage: heavyscript git [-b | --branch | -g | --global | -h | --help]"
            exit 1
            ;;
    esac
}