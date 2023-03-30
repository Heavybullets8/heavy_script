#!/bin/bash


backup_handler() {
  local args=("$@")
  local action=$1

  case $action in
    -c|--create)
      if ! [[ ${args[2]} =~ ^[0-9]+$  ]]; then
        echo -e "Error: -c|--create needs to be assigned an interger\n\"""${args[2]}""\" is not an interger" >&2
        exit
      fi
      create_backup "${args[2]}"
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
      echo "Unknown backup action: $action"
      echo "Usage: heavyscript backup [-c | --create | -r | --restore | -d | --delete | -h | --help]"
      exit 1
      ;;
  esac
}
