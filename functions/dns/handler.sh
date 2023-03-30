#!/bin/bash


dns_handler() {
    local args=("$@")
    local no_config=false

    # Check if the help option or --no-config is in the arguments
    if check_help "${args[@]}"; then
        dns_help
        exit
    fi
    # Check if --no-config is in the arguments
    if check_no_config "${args[@]}"; then
        no_config=true
    fi

    # Load the config.ini file if --no-config is not passed
    if ! $no_config; then
        read_ini "config.ini" --prefix DNS
    fi

    # Set the default option using the config file
    local verbose="${DNS__DNS__verbose:-false}"

    if [[ "$verbose" == "true" ]]; then
        option="-a"
    else
        option="$1"
    fi


    case "$option" in
        -a|--all)
            # Call the function to display all DNS information
            dns_verbose
            ;;
        "")
            dns_non_verbose
            ;;
        *)
            echo "Invalid option: $option"
            echo "Usage: heavyscript dns [-a | --all | -h | --help]"
            exit 1
            ;;
    esac
}





