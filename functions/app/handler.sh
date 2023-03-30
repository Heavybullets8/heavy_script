#!/bin/bash


app_handler() {
  local action=$1
  shift # Remove action from the arguments

  case $action in
    -s|--start)
      start_app_prompt
      ;;
    -x|--stop)
      stop_app_prompt
      ;;
    -r|--restart)
      restart_app_prompt
      ;;
    -d|--delete)
      delete_app_prompt
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
