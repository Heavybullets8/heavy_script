#!/bin/bash


dns_handler() {
  local option="$1"

  case "$option" in
    --all)
      # Call the function to display all DNS information
      dns_verbose
      ;;
    --help)
      # Call the function to display help for the dns command
      dns_help
      ;;
    *)
      # Call the function to display a default dns action or an error message
      dns_non_verbose
      ;;
  esac
}

