#!/bin/bash


dns_handler() {
  # Load the config.ini file
  read_ini "config.ini" --prefix DNS

  # Set the default option using the config file
  local verbose="${DNS__DNS__verbose:-false}"

  if [[ "$verbose" == "true" ]]; then
    option="-a"
  else
    option="$1"
  fi

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



