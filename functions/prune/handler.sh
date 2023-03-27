#!/bin/bash


prune_handler() {
  local option="$1"


  case "$option" in
    --help)
      # Call the function to display help for the pvc command
      prune_help
      ;;
    "")
        prune
        return
        ;;
    *)
      echo "Invalid option: $option"
      echo "Usage: heavyscript prune [--help]"
      exit 1
      ;;
  esac
}