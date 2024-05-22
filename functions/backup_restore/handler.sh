#!/bin/bash

# Function to handle backups and exports
backup_and_export() {
    local dataset_path="$1"
    local retention="$2"

    # Load the config.ini file if --no-config is not passed
    if [[ $no_config == false ]]; then
        read_ini "config.ini" --prefix BACKUP
    fi

    # Set the default option using the config file
    local export_enabled="${BACKUP__BACKUP__export_enabled:-false}"
    local full_backup_enabled="${BACKUP__BACKUP__full_backup_enabled:-false}"
    local custom_dataset_location="${BACKUP__BACKUP__custom_dataset_location:-}"

    if [[ -n "$custom_dataset_location" ]]; then
        dataset_path="$custom_dataset_location"
    fi

    if [[ "$export_enabled" == "true" ]]; then
        echo -e "🄱 🄰 🄲 🄺 🅄 🄿 🅂\n"
        echo -e "Running export with retention: $retention\n"
        python3 functions/backup_restore/main.py "$dataset_path" export --retention "$retention"
        echo -e "\nExport completed.\n"
    fi
    if [[ "$full_backup_enabled" == "true" ]]; then
        echo -e "Running full backup with retention: $retention\n"
        python3 functions/backup_restore/main.py "$dataset_path" backup_all --retention "$retention"
        echo -e "\nFull backup completed.\n"
    fi
}

# Main handler function
backup_handler() {
    local args=("$@")
    config_file="config.ini"

    if [[ ! -f "$config_file" ]]; then
        echo "Error: Configuration file 'config.ini' not found."
        exit 1
    fi

    default_dataset_path="/mnt/$(get_apps_pool)/heavyscript_backups"
    
    case "${args[0]}" in
        -c|--create)
            if [[ -z "${args[1]}" ]]; then
                read -rp "Enter retention number: " retention
            else
                retention="${args[1]}"
            fi

            if ! [[ $retention =~ ^[0-9]+$ ]]; then
                echo -e "Error: \"$retention\" needs to be assigned an integer\n\"$retention\" is not an integer" >&2
                exit 1
            fi
            backup_and_export "$default_dataset_path" "$retention"
            ;;
        -r|--restore)
            if [[ -z "${args[1]}" ]]; then
                python3 functions/backup_restore/main.py "$default_dataset_path" restore_all
            else
                python3 functions/backup_restore/main.py "$default_dataset_path" restore_all "${args[1]}"
            fi
            ;;
        -d|--delete)
            if [[ -z "${args[1]}" ]]; then
                python3 functions/backup_restore/main.py "$default_dataset_path" delete
            else
                python3 functions/backup_restore/main.py "$default_dataset_path" delete "${args[1]}"
            fi
            ;;
        -h|--help)
            echo "Usage: $0 {-c|--create <retention> | -r|--restore [backup_name] | -d|--delete [backup_name] | -l|--list | -i|--import <backup_name> <app_name> | -h|--help}"
            ;;
        -l|--list)
            python3 functions/backup_restore/main.py "$default_dataset_path" list
            ;;
        -i|--import)
            if [[ -z "${args[1]}" ]]; then
                python3 functions/backup_restore/main.py "$default_dataset_path" import
            elif [[ -z "${args[2]}" ]]; then
                echo "Error: Missing app name for import."
                exit 1
            else
                python3 functions/backup_restore/main.py "$default_dataset_path" import "${args[1]}" "${args[2]}"
            fi
            ;;
        *)
            echo "Unknown backup action: $1"
            echo "Usage: $0 {-c|--create <retention> | -r|--restore [backup_name] | -d|--delete [backup_name] | -l|--list | -i|--import <backup_name> <app_name> | -h|--help}"
            exit 1
            ;;
    esac
}