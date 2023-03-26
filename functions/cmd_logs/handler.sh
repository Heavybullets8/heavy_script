#!/bin/bash

pod_handler() {
  local option="$1"

  case "$option" in
    --logs)
      # Call the function to display container logs
      container_shell_or_logs "logs"
      ;;
    --shell)
      # Call the function to open a shell for the container
      container_shell_or_logs "shell"
      ;;
    --help)
      # Call the function to display help for the pod command
      pod_help
      ;;
    *)
      echo "Invalid option: $option"
      echo "Usage: heavyscript pod [--logs | --shell | --help]"
      exit 1
      ;;
  esac
}
