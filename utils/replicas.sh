#!/bin/bash

pull_replicas() {
    local app_name
    app_name="$1"

    midclt call chart.release.get_instance "$app_name" | jq '.config.controller.replicas // .config.workload.main.replicas // .pod_status.desired'
}
