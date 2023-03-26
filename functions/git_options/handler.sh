#!/bin/bash


self_update_handler() {
  local args=("$@")
  local self_update=false

  for arg in "${args[@]}"; do
    if [[ "$arg" == "self-update" ]]; then
      self_update=true
      break
    fi
  done

  if $self_update; then
    perform_self_update

    # Remove 'self-update' from the arguments array
    args=("${args[@]/self-update/}")

    # Re-run the script with the remaining arguments after the update
    exec "$(basename "$0")" "${args[@]}"
  fi
}


git_handler() {
  local option="$1"

  case "$option" in
    --branch)
      # Call the function to choose a branch
      choose_branch
      ;;
    --global-path)
      # Call the function to add the script to the global path
      add_script_to_global_path
      ;;
    --help)
      # Call the function to display help for the git command
      git_help
      ;;
    *)
      echo "Invalid option: $option"
      echo "Usage: heavyscript git [--choose-branch | --global-path]"
      exit 1
      ;;
  esac
}
