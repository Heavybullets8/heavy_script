#!/bin/bash


self_update_handler() {
  local args=("$@")
  local self_update=false

  for arg in "${args[@]}"; do
    if [[ "$arg" == "self-update" || "$arg" == "-u" ]]; then
      self_update=true
      break
    fi
  done

  if $self_update; then
    self_update
  fi
}


git_handler() {
  local option="$1"

  case "$option" in
    -b|--branch)
      # Call the function to choose a branch
      choose_branch
      ;;
    -g|--global)
      # Call the function to add the script to the global path
      add_script_to_global_path
      ;;
    -h|--help)
      # Call the function to display help for the git command
      git_help
      ;;
    *)
      echo "Invalid option: $option"
      echo "Usage: heavyscript git [-c | --choose-branch | -g | --global | -h | --help]"
      exit 1
      ;;
  esac
}
