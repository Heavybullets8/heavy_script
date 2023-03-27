#!/bin/bash


dns_handler() {
  local option="$1"

  case "$option" in
    -a|--all)
      # Call the function to display all DNS information
      dns_verbose
      ;;
    -h|--help)
      # Call the function to display help for the dns command
      dns_help
      ;;
    "")
      dns_non_verbose
      ;;
    *)
      echo "Invalid option: $option"
      echo "Usage: heavyscript dns [-a | --all | -h | --help]"
      exit 1
      ;;
  esac
}

