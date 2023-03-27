#!/bin/bash

app_handler() {
  local action=$1
  shift # Remove action from the arguments

  case $action in
    --start)
      start_app
      ;;
    --stop)
      stop_app
      ;;
    --restart)
      restart_app
      ;;
    --delete)
      delete_app
      ;;
    --help)
      app_help
      ;;
    *)
      echo "Unknown app action: $action"
      exit 1
      ;;
  esac
}
