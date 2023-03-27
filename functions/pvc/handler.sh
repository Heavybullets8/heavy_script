#!/bin/bash

pvc_handler() {
  local option="$1"

  # If no arguments are provided, call the mount_prompt function
  if [ -z "$option" ]; then
    mount_prompt
    return
  fi

  case "$option" in
    -m | --mount)
      # Call the function to mount the app
      mount_app_func
      ;;
    -u | --unmount)
      # Call the function to unmount the app
      unmount_app_func
      ;;
    -h | --help)
      # Call the function to display help for the pvc command
      pvc_help
      ;;
    *)
      echo "Invalid option: $option"
      echo "Usage: heavyscript pvc [-m | --mount | -u | --unmount | -h | --help]"
      exit 1
      ;;
  esac
}
