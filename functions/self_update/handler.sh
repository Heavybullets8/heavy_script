#!/bin/bash


self_update_handler() {
  local args=("$@")
  local self_update=false
  local no_self_update=false
  local include_major=false

  for arg in "${args[@]}"; do
      if [[ "$arg" =~ ^(--)?self-update$ || "$arg" == "-U" ]]; then
          self_update=true
      elif [[ "$arg" == "--no-self-update" ]]; then
          no_self_update=true
          break
      elif [[ "$arg" == "--help" || "$arg" == "-h" ]]; then
          self_update_help
          exit 0
      elif [[ "$arg" == "--force" ]]; then
          include_major=true
      fi
  done

  if $self_update && ! $no_self_update; then
      self_update 
  fi
}
export -f self_update_handler
