#!/bin/bash


sync_handler() {
  local option="$1"


  case "$option" in
    --help)
      # Call the function to display help for the pvc command
      sync_help
      ;;
    "")
        sync_catalog
        return
        ;;
    *)
      echo "Invalid option: $option"
      echo "Usage: heavyscript sync [--help]"
      exit 1
      ;;
  esac
}