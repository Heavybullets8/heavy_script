#!/bin/bash


update_handler() {
    declare -x concurrent
    declare -x timeout
    declare -x ignore
    declare -x rollback
    declare -x stop_before_update
    declare -x update_all_apps
    declare -x verbose
    declare -x ignore_image_update
    declare -x update_only
    local sync
    local number_of_backups
    local prune

    parse_app_names() {
        IFS=',' read -ra ADDR <<< "$1"
        for i in "${ADDR[@]}"; do
            if ! [[ $i =~ ^[a-zA-Z]([-a-zA-Z0-9,]*[a-zA-Z0-9])?$ ]]; then
                echo -e "Error: \"$i\" is not a possible option for an application name"
                exit
            fi
            eval "$2+=('$i')"
        done
    }

    # Check if --no-config is in the arguments
    if [[ $no_config == false ]]; then
        read_ini "config.ini" --prefix UPDATE
    fi

    # Set variables from config.ini if they exist
    concurrent="${UPDATE__UPDATE__concurrent:-1}"
    timeout="${UPDATE__UPDATE__timeout:-500}"
    number_of_backups="${UPDATE__UPDATE__backup:-}"
    update_all_apps="${UPDATE__UPDATE__include_major:-false}"
    ignore_image_update="${UPDATE__UPDATE__ignore_img:-false}"
    prune="${UPDATE__UPDATE__prune:-false}"
    rollback="${UPDATE__UPDATE__rollback:-false}"
    sync="${UPDATE__UPDATE__sync:-false}"
    stop_before_update="${UPDATE__UPDATE__stop_before_update:-false}"
    verbose="${UPDATE__UPDATE__verbose:-false}"

    # Get the ignore value from config.ini
    ignore_value="${UPDATE__UPDATE__ignore:-}"

    # Split comma-separated values into an array
    IFS=',' read -ra ignore <<< "$ignore_value"

    while [[ "$#" -gt 0 ]]; do
        case $1 in
            -a|--include-major)
                update_all_apps=true
                shift
                ;;
            -b|--backup)
                shift
                if ! [[ $1 =~ ^[0-9]+$  ]]; then
                    echo -e "Error: -b needs to be assigned an interger\n\"""$1""\" is not an interger" >&2
                    exit
                fi
                if [[ "$1" -le 0 ]]; then
                    echo "Error: Number of backups is required to be at least 1"
                    exit
                fi
                number_of_backups="$1"
                shift
                ;;
            -c|--concurrent)
                shift
                if ! [[ $1 =~ ^[0-9]+$  ]]; then
                    echo -e "Error: -c needs to be assigned an interger\n\"""$1""\" is not an interger" >&2
                    exit
                fi
                if [[ "$1" -le 0 ]]; then
                    echo "Error: Number of concurrent updates is required to be at least 1"
                    exit
                fi
                concurrent="$1"
                shift
                ;;
            -h|--help)
                update_help
                exit
                ;;
            -i|--ignore)
                shift
                parse_app_names "$1" ignore
                shift
                ;;
            -I|--ignore-img)
                ignore_image_update=true
                shift
                ;;
            -p|--prune)
                prune=true
                shift
                ;;
            -r|--rollback)
                rollback=true
                shift
                ;;
            -s|--sync)
                sync=true
                shift
                ;;
            -x|--stop)
                stop_before_update=true
                shift
                ;;
            -t|--timeout)
                shift
                timeout=$1
                if ! [[ $timeout =~ ^[0-9]+$ ]]; then
                    echo -e "Error: -t needs to be assigned an interger\n\"""$timeout""\" is not an interger" >&2
                    exit
                fi
                shift
                ;;
            -u|--update-only)
                shift
                parse_app_names "$1" update_only
                shift
                ;;
            -v|--verbose)
                verbose=true
                shift
                ;;
            *)
                echo "Unknown update option: $1"
                update_help
                exit 1
                ;;
        esac
    done

    if [[ "$number_of_backups" -ge 1 && "$sync" == true ]]; then # Run backup and sync at the same time
        echo "🅃 🄰 🅂 🄺 🅂 :"
        echo -e "-Backing up ix-applications dataset\n-Syncing catalog(s)"
        echo -e "Please wait for output from both tasks..\n\n"
        create_backup "$number_of_backups" "update" &
        sync_catalog "update" &
        wait
    elif [[ "$number_of_backups" -ge 1 ]]; then # If only backup is true, run it
        echo "🅃 🄰 🅂 🄺 :"
        echo -e "-Backing up ix-applications dataset\nPlease wait..\n\n"
        create_backup "$number_of_backups" "update"
    elif [[ "$sync" == true ]]; then # If only sync is true, run it
        echo "🅃 🄰 🅂 🄺 :"
        echo -e "Syncing Catalog(s)\nThis can take a few minutes, please wait..\n\n"
        sync_catalog "update"
    fi

    commander

    if [[ "$prune" == true ]]; then
        prune 
    fi
}
