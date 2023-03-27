#!/bin/bash


update_help() {
  echo -e "Usage: heavyscript update [OPTIONS]\n"
  echo -e "Update your applications.\n"

  echo -e "${bold}OPTIONS${reset}:"
  echo -e "${blue}-A, --all${reset}\t\tUpdate through major version changes"
  echo -e "${blue}-b, --backup${reset}\t\tSet the number of backups to keep (default: 14)"
  echo -e "${blue}-c, --concurrent${reset}\tUpdate COUNT applications concurrently (default: 1)"
  echo -e "${blue}-h, --help${reset}\t\tShow this help message and exit"
  echo -e "${blue}-i, --ignore${reset}\t\tIgnore updating the specified application"
  echo -e "${blue}-I, --ignore-img${reset}\tIgnore container image updates"
  echo -e "${blue}-p, --prune${reset}\t\tPrune unused images after the update"
  echo -e "${blue}-r, --rollback${reset}\t\tRoll back to the previous version if update failure"
  echo -e "${blue}-s, --sync${reset}\t\tSync the application images before updating"
  echo -e "${blue}-S, --stop${reset}\t\tStop the application before updating"
  echo -e "${blue}-t, --timeout${reset}\t\tSet the timeout for the update process in seconds (default: 500)"
  echo -e "${blue}-u, --self-update${reset}\tUpdate HeavyScript itself"
  echo -e "${blue}-v, --verbose${reset}\t\tDisplay verbose output\n"

  echo -e "${bold}Example${reset}:"
  echo -e "  ${blue}heavyscript update -c 10 -b 20 -i radarr -i sonarr -t 60 -sSpv --all${blue}\n"
  echo -e "This command will update all applications,"
  echo -e "updating 10 applications concurrently,"
  echo -e "keeping 20 backups, ignoring the 'radarr' and 'sonarr' applications,"
  echo -e "setting a timeout of 60 seconds,"
  echo -e "syncing images before updating,"
  echo -e "stopping the application before updating,"
  echo -e "pruning unused images after the update,"
  echo -e "and displaying verbose output.\n"
}

