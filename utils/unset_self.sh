#!/bin/bash


remove_options_args() {
  local options_to_remove=("${@:1:$#-1}")
  local input_args=("${!#}")

  local output_args=()

  for arg in "${input_args[@]}"; do
    local should_remove=false
    for option_to_remove in "${options_to_remove[@]}"; do
      if [[ "$arg" == "$option_to_remove" ]]; then
        should_remove=true
        break
      elif [[ "$option_to_remove" == "self-update" && ( "$arg" =~ ^(--)?self-update$ || "$arg" == "-U" ) ]]; then
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
