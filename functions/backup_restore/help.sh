#!/bin/bash


backup_help() {
  cat << EOF
Usage: heavyscript backup [OPTIONS]

Manage backup and restore operations on the ix-applications dataset.

Options:
  --create       Create a backup of the ix-applications dataset.
  --restore      Restore the ix-applications dataset from a backup.
  --delete       Delete a backup of the ix-applications dataset.
  --help         Show this help message and exit.

Example usage:
  heavyscript backup --create    # Create a backup
  heavyscript backup --restore   # Restore from a backup
  heavyscript backup --delete    # Delete a backup
  heavyscript backup --help      # Display this help message
EOF
}