#!/bin/bash


update_help() {
  cat << EOF
Usage: heavyscript update [OPTIONS]

Update your applications.

OPTIONS:
  -c COUNT        Update COUNT applications concurrently (default: 1)
  -b BACKUPS      Set the number of backups to keep (default: 14)
  -r              Rollback to the previous version on failure
  -i APP_NAME     Ignore updating the specified application
  -t TIMEOUT      Set the timeout for the update process in seconds
  -s              Sync the application images before updating
  -S              Stop the application before updating
  -p              Prune unused images after the update
  -v              Display verbose output
  --all           Update all applications

Example:
  heavyscript update -c 10 -b 20 -i radarr -i sonarr -t 60 -sSpv --all

This command will update all applications, updating 2 applications concurrently, keeping 3 backups, ignoring the 'myapp' application, setting a timeout of 60 seconds, syncing images before updating, stopping the application before updating, pruning unused images after the update, and displaying verbose output.

EOF
}
