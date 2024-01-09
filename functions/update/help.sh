#!/bin/bash


update_help() {
    echo -e "Usage: heavyscript update [OPTIONS]\n"
    echo -e "Update your applications.\n"

    echo -e "${bold}OPTIONS${reset}:"
    echo -e "${blue}-a, --include-major${reset}    Update the application even if it is a major version update"
    echo -e "${blue}-b, --backup${reset}           Set the number of backups to keep (default: 14)"
    echo -e "${blue}-c, --concurrent${reset}       Update COUNT applications concurrently (default: 1)"
    echo -e "${blue}-h, --help${reset}             Show this help message and exit"
    echo -e "${blue}-i, --ignore${reset}           Ignore updating the specified application(s)"
    echo -e "${blue}-I, --ignore-img${reset}       Ignore container image updates"
    echo -e "${blue}-p, --prune${reset}            Prune unused images after the update"
    echo -e "${blue}-r, --rollback${reset}         Roll back to the previous version if update failure"
    echo -e "${blue}-s, --sync${reset}             Sync the application images before updating"
    echo -e "${blue}-x, --stop${reset}             Stop the application before updating (Not recommended))"
    echo -e "${blue}-t, --timeout${reset}          Set the timeout for the update process in seconds (default: 500)"
    echo -e "${blue}-u, --update-only${reset}      Only update the specified application(s)"
    echo -e "${blue}-U, --self-update${reset}      Update HeavyScript itself"
    echo -e "${blue}-v, --verbose${reset}          Display verbose output\n"
    echo -e "${blue}--no-config${reset}            Ignore the settings in your config.ini file"
    echo
    echo -e "${bold}Note${reset}:"
    echo -e "    It does not matter in which order you specify the options after the update command."
    echo 
    echo -e "${bold}Example${reset}:"
    echo -e "  ${blue}heavyscript update -c 10 -b 20 -U -i radarr -i sonarr -t 60 -sxpv --include-major --no-config${blue}\n"
    echo -e "This command will do the following:"
    echo -e "    Update all applications including major version updates"
    echo -e "    Update 10 applications concurrently"
    echo -e "    keep up to 20 Heavyscript/Truetool backups"
    echo -e "    Update HeavyScript itself"
    echo -e "    Ignore the 'radarr' and 'sonarr' applications"
    echo -e "    Set a timeout of 60 seconds"
    echo -e "    Sync the catalog before updating"
    echo -e "    Stop the application before updating"
    echo -e "    Prune unused images after the update"
    echo -e "    Display verbose output"
    echo -e "    Ignore the settings in your config.ini file\n"
}
