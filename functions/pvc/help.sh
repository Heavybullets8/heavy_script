#!/bin/bash

pvc_help() {
  cat << EOF
Usage: heavyscript pvc [OPTIONS]

Manage k3s PVC data.

Options:
  --mount      Mount the specified k3s PVC data to an app.
  --unmount    Unmount the specified k3s PVC data from an app.
  --help       Show this help message and exit.

Examples:
  heavyscript pvc --mount   # Mount k3s PVC data to an app
  heavyscript pvc --unmount # Unmount k3s PVC data from an app

EOF
}
