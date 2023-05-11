#!/bin/bash


backup_handler() {
    local args=("$@")

    case "${args[0]}" in
        -c|--create)
            if ! [[ ${args[1]} =~ ^[0-9]+$  ]]; then
                echo -e "Error: \"${args[1]}\" needs to be assigned an interger\n\"""${args[1]}""\" is not an interger" >&2
                exit
            fi
            create_backup "${args[1]}" "direct"
            ;;
        -r|--restore)
            restore_backup
            ;;
        -d|--delete)
            delete_backup
            ;;
        -h|--help)
            backup_help
            ;;
        *)
            echo "Unknown backup action: ${args[0]}"
            backup_help
            exit 1
            ;;
    esac
}