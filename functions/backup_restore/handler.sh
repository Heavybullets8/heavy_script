#!/bin/bash

backup_handler() {
  local action=$1
  shift # Remove action from the arguments

  case $action in
    --create)
      create_backup "$@"
      ;;
    --restore)
      restore_backup
      ;;
    --delete)
      delete_backup
      ;;
    --help)
      backup_help
      ;;
    *)
      echo "Unknown backup action: $action"
      backup_help
      exit 1
      ;;
  esac
}