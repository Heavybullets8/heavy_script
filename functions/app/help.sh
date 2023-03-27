#!/bin/bash

app_help() {
  cat << EOF
Usage: heavyscript app [OPTIONS]

Manage the application lifecycle. Each action opens a menu for selecting an application.

Options:
  --start        Start the application.
  --stop         Stop the application.
  --restart      Restart the application.
  --delete       Delete the application.
  --help         Show this help message and exit.

Example usage:
  heavyscript app --start     # Open a menu to select and start the application
  heavyscript app --stop      # Open a menu to select and stop the application
  heavyscript app --restart   # Open a menu to select and restart the application
  heavyscript app --delete    # Open a menu to select and delete the application
  heavyscript app --help      # Display this help message
EOF
}
