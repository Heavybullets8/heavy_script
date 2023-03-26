#!/bin/bash


update_handler() {
  local opt
  while getopts ":b:ri:t:sSc:pv-:" opt; do
    case "$opt" in
        -)
            case "${OPTARG}" in
                all)
                    all=true
                    ;;
                help)
                    help=true
                    ;;
                *)
                    echo -e "Invalid Option \"--$OPTARG\"\n"
                    help
                    ;;
            esac
            ;;
      c)
        concurrent_updates="$OPTARG"
        if ! [[ "$concurrent_updates" =~ ^[0-9]+$ ]]; then
          echo "Error: -c needs to be assigned an integer" >&2
          echo "\"$concurrent_updates\" is not an integer" >&2
          exit 1
        fi
        ;;
      b)
        number_of_backups=$OPTARG
        if ! [[ $OPTARG =~ ^[0-9]+$  ]]; then
            echo -e "Error: -b needs to be assigned an interger\n\"""$number_of_backups""\" is not an interger" >&2
            exit
        fi
        if [[ "$number_of_backups" -le 0 ]]; then
            echo "Error: Number of backups is required to be at least 1"
            exit
        fi
        ;;
      r)
        rollback=true
        ;;
      i)
        if ! [[ $OPTARG =~ ^[a-zA-Z]([-a-zA-Z0-9]*[a-zA-Z0-9])?$ ]]; then # Using case insensitive version of the regex used by Truenas Scale
            echo -e "Error: \"$OPTARG\" is not a possible option for an application name"
            exit
        else
            ignore+=("$OPTARG")
        fi
        ;;
      t)
        timeout=$OPTARG
        if ! [[ $timeout =~ ^[0-9]+$ ]]; then
            echo -e "Error: -t needs to be assigned an interger\n\"""$timeout""\" is not an interger" >&2
            exit
        fi
        ;;
      s)
        sync=true
        ;;
      S)
        stop_before_update=true
        ;;
      p)
        prune=true
        ;;
      v)
        verbose=true
        ;;
      *)
        echo "Invalid option: -$OPTARG" >&2
        exit 1
        ;;
    esac
  done

  # Remove the processed options
  shift $((OPTIND-1))

  # Check for --all option
  if [[ "$1" == "--all" ]]; then
    # Your logic for --all option
    shift # Remove '--all' from the arguments
  fi

  # If there are remaining arguments, show an error
  if [[ "$#" -gt 0 ]]; then
    echo "Unknown arguments: $*" >&2
    exit 1
  fi
}

# In the main script, you can call the handler like this:
# update_handler "${args[@]}"
