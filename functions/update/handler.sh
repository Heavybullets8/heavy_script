#!/bin/bash


update_handler() {
  local backup=14
  local concurrent=1
  local timeout=500
  local ignore=()
  local prune=false
  local rollback=false
  local sync=false
  local stop_before_update=false
  local update_all_apps=false
  local verbose=false


  while [[ "$#" -gt 0 ]]; do
    case $1 in
      -A|--all)
        update_all_apps=true
        shift
        ;;
      -b|--backup)
        shift
        if ! [[ $1 =~ ^[0-9]+$  ]]; then
            echo -e "Error: -b needs to be assigned an interger\n\"""$1""\" is not an interger" >&2
            exit
        fi
        if [[ "$1" -le 0 ]]; then
            echo "Error: Number of backups is required to be at least 1"
            exit
        fi
        backup="$1"
        shift
        ;;
      -c|--concurrent)
        shift
        concurrent="$1"
        shift
        ;;
      -h|--help)
        # Handle --help option here
        update_help
        exit
        ;;
      -i|--ignore)
        shift
        if ! [[ $1 =~ ^[a-zA-Z]([-a-zA-Z0-9]*[a-zA-Z0-9])?$ ]]; then # Using case insensitive version of the regex used by Truenas Scale
            echo -e "Error: \"$1\" is not a possible option for an application name"
            exit
        else
            ignore+=("$1")
        fi
        
        shift
        ;;
      -I|--ignore-img)
        # Handle --ignore-img option here
        shift
        ;;
      -p|--prune)
        prune=true
        shift
        ;;
      -r|--rollback)
        rollback=true
        shift
        ;;
      -s|--sync)
        sync=true
        shift
        ;;
      -S|--stop)
        stop_before_update=true
        shift
        ;;
      -t|--timeout)
        shift
        timeout=$1
        if ! [[ $timeout =~ ^[0-9]+$ ]]; then
            echo -e "Error: -t needs to be assigned an interger\n\"""$timeout""\" is not an interger" >&2
            exit
        fi
        shift
        ;;
      -u|--self-update)
        self_update_handler
        shift
        ;;
      -v|--verbose)
        verbose=true
        shift
        ;;
      *)
        echo "Unknown update option: $1"
        exit 1
        ;;
    esac
  done

  if [[ "$number_of_backups" -gt 1 && "$sync" == true ]]; then # Run backup and sync at the same time
      echo "🅃 🄰 🅂 🄺 🅂 :"
      echo -e "-Backing up ix-applications dataset\n-Syncing catalog(s)"
      echo -e "Please wait for output from both tasks..\n\n"
      create_backup &
      sync_catalog &
      wait
  elif [[ "$number_of_backups" -gt 1 ]]; then # If only backup is true, run it
      echo "🅃 🄰 🅂 🄺 :"
      echo -e "-Backing up ix-applications dataset\nPlease wait..\n\n"
      create_backup
  elif [[ "$sync" == true ]]; then # If only sync is true, run it
      echo "🅃 🄰 🅂 🄺 :"
      echo -e "Syncing Catalog(s)\nThis can take a few minutes, please wait..\n\n"
      sync_catalog
  fi

  commander

  if [[ "$prune" == true ]]; then
      prune 
  fi

}
