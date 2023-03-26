#!/bin/bash


update_help() {
  cat << EOF
Usage: heavyscript update [OPTIONS]

Update your applications.

${bold}OPTIONS${reset}:
  -A, --all           Update through major version changes
  -b, --backup        Set the number of backups to keep (default: 14)
  -c, --concurrent    Update COUNT applications concurrently (default: 1)
  -h, --help          Show this help message and exit
  -i, --ignore        Ignore updating the specified application
  -I, --ignore-img    Ignore container image updates
  -p, --prune         Prune unused images after the update
  -r, --rollback      Roll back to the previous version if update failure
  -s, --sync          Sync the application images before updating
  -S, --stop          Stop the application before updating
  -t, --timeout       Set the timeout for the update process in seconds (default: 500)
  -u, --self-update   Update HeavyScript itself
  -v, --verbose       Display verbose output

${bold}Example${reset}:
  heavyscript update -c 10 -b 20 -i radarr -i sonarr -t 60 -sSpv --all

This command will update all applications,
updating 10 applications concurrently,
keeping 20 backups, ignoring the 'radarr' and 'sonarr' applications,
setting a timeout of 60 seconds,
syncing images before updating,
stopping the application before updating,
pruning unused images after the update,
and displaying verbose output.

EOF
}
