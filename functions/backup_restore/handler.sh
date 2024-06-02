#!/bin/bash

# Function to read the config.ini file
read_config() {
    if [[ $no_config == false ]]; then
        read_ini "config.ini" --prefix BACKUP
    fi

    # Set the default options using the config file
    export export_enabled="${BACKUP__BACKUP__export_enabled:-false}"
    export full_backup_enabled="${BACKUP__BACKUP__full_backup_enabled:-false}"
    export dataset_path
    if [[ "${BACKUP__BACKUP__dataset_absolute_path:-"DEFAULT"}" == "DEFAULT" ]]; then
        dataset_path="/mnt/$(get_apps_pool)/heavyscript_backups"
    else
        dataset_path="${BACKUP__BACKUP__dataset_absolute_path:-"/mnt/$(get_apps_pool)/heavyscript_backups"}"
    fi
}

# Function to handle backups and exports
backup_and_export() {
    local retention="$1"

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

    read_config

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
            backup_and_export "$retention"
            ;;
        -A|--restore-all)
            if [[ -z "${args[1]}" ]]; then
                python3 functions/backup_restore/main.py "$dataset_path" restore_all
            else
                python3 functions/backup_restore/main.py "$dataset_path" restore_all "${args[1]}"
            fi
            ;;
        -S|--restore-single)
            if [[ -z "${args[1]}" ]]; then
                python3 functions/backup_restore/main.py "$dataset_path" restore_single
            else
                python3 functions/backup_restore/main.py "$dataset_path" restore_single "${args[1]}"
            fi
            ;;
        -d|--delete)
            if [[ -z "${args[1]}" ]]; then
                python3 functions/backup_restore/main.py "$dataset_path" delete
            else
                python3 functions/backup_restore/main.py "$dataset_path" delete "${args[1]}"
            fi
            ;;
        -h|--help)
            backup_help
            ;;
        -l|--list)
            python3 functions/backup_restore/main.py "$dataset_path" list
            ;;
        -i|--import)
            if [[ -z "${args[1]}" ]]; then
                python3 functions/backup_restore/main.py "$dataset_path" import
            elif [[ -z "${args[2]}" ]]; then
                echo "Error: Missing app name for import."
                exit 1
            else
                python3 functions/backup_restore/main.py "$dataset_path" import "${args[1]}" "${args[2]}"
            fi
            ;;
        *)
            echo "Unknown backup action: $1"
            backup_help
            exit 1
            ;;
    esac
}