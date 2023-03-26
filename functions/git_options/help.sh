#!/bin/bash


git_help() {
  cat << EOF
Usage: heavyscript git [OPTIONS]

Options:
  --branch        Choose a different branch for the script
  --global-path   Add the script to the global path

Example:
  heavyscript git --branch
  heavyscript git --global-path
EOF
}
