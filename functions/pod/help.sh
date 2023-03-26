#!/bin/bash


pod_help() {
  cat << EOF
Usage: heavyscript pod [OPTIONS]

Interact with the containers within Kubernetes pods.

Options:
  --logs         Display the logs of a container.
  --shell        Open a shell for a container.
  --help         Show this help message and exit.

Example usage:
  heavyscript pod --logs      # Display container logs
  heavyscript pod --shell     # Open a shell for a container
  heavyscript pod --help      # Display this help message
EOF
}
