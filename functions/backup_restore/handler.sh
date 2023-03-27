#!/bin/bash


backup_handler() {
  local action=$1

  case $action in
    -c|--create)
      create_backup "$@"
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
