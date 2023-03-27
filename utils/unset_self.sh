#!/bin/bash


remove_self_update_args() {
  local input_args=("$@")
  local output_args=()

  for arg in "${input_args[@]}"; do
    if ! [[ "$arg" =~ ^(--)?self-update$ || "$arg" == "-U" ]]; then
      output_args+=("$arg")
    fi
  done

  echo "${output_args[@]}"
}
