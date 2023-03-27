#!/bin/bash


app_handler() {
  local action=$1
  shift # Remove action from the arguments

  case $action in
    -s|--start)
      start_app
      ;;
    -x|--stop)
      stop_app
      ;;
    -r|--restart)
      restart_app
      ;;
    -d|--delete)
      delete_app
      ;;
    -h|--help)
      app_help
      ;;
    *)
      echo "Unknown app action: $action"
      echo "Usage: heavyscript app [-s | --start | -x | --stop | -r | --restart | -d | --delete | -h | --help]"
      exit 1
      ;;
  esac
}
