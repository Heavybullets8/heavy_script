#!/bin/bash


remove_options_args() {
  local options_to_remove=("$@")
  local input_args
  input_args=("${options_to_remove[-1]}")
  unset "options_to_remove[${#options_to_remove[@]}-1]"

  local output_args=()
  
  for arg in "${input_args[@]}"; do
    local should_remove=false
    for option_to_remove in "${options_to_remove[@]}"; do
      if [[ "$arg" == "$option_to_remove" ]] ||
         { [[ "$option_to_remove" == "self-update" ]] && { [[ "$arg" =~ ^(--)?self-update$ ]] || [[ "$arg" == "-U" ]]; }; }; then
        should_remove=true
        break
      fi
    done
    if ! $should_remove; then
      output_args+=("$arg")
    fi
  done

  printf "%s\n" "${output_args[@]}"
}

