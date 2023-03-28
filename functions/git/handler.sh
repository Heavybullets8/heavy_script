#!/bin/bash


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
export -f git_handler