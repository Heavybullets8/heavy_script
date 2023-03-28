#!/bin/bash


self_update_handler() {
  local args=("$@")
  local self_update=false
  local no_self_update=false
  local include_major=false

 # Check if second element is a --help/-h argument
    if [[ "${args[1]}" == "--help" || "${args[1]}" == "-h" ]]; then
        self_update_help
        exit
    fi

  for arg in "${args[@]}"; do
      if [[ "$arg" =~ ^(--)?self-update$ || "$arg" == "-U" ]]; then
          self_update=true
      elif [[ "$arg" == "--no-self-update" ]]; then
          no_self_update=true
          break
      elif [[ "$arg" == "--major" ]]; then
          include_major=true
      fi
  done

  if $self_update && ! $no_self_update; then
      self_update 
  fi


    # Clean args



}
export -f self_update_handler
