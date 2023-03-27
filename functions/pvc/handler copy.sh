#!/bin/bash


pvc_handler() {
  local option="$1"


  case "$option" in
    --mount)
      # Call the function to mount the app
      mount_app_func
      ;;
    --unmount)
      # Call the function to unmount the app
      unmount_app_func
      ;;
    --help)
      # Call the function to display help for the pvc command
      pvc_help
      ;;
    "")
        mount_prompt
        return
        ;;
    *)
      echo "Invalid option: $option"
      echo "Usage: heavyscript pvc [--mount | --unmount | --help]"
      exit 1
      ;;
  esac
}