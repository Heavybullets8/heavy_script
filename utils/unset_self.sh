#!/bin/bash


remove_option_args() {
  local option_to_remove="$1"
  shift
  local input_args=("$@")
  local output_args=()

  for arg in "${input_args[@]}"; do
    if ! { [[ "$arg" == "$option_to_remove" ]] || 
         { [[ "$option_to_remove" == "self-update" ]] && { [[ "$arg" =~ ^(--)?self-update$ ]] || [[ "$arg" == "-U" ]]; }; }; }; then
      output_args+=("$arg")
    fi
  done

  printf "%s\n" "${output_args[@]}"
}
