#!/bin/bash


check_filtered_apps() {
    # Define a function to process each app name
    process_app_name() {
        local app_name=$1

        midclt call chart.release.get_instance "$app_name" | jq -r '
            if .chart_metadata.name == "prometheus" then
                .name + ",operator"
            elif .config.operator.enabled == true then
                .name + ",operator"
            elif .catalog_train == "operators" then
                .name + ",operator"
            else
                empty
            end,
            if .catalog == "TRUENAS" then
                .name + ",official"
            else
                empty
            end,
            if .config.cnpg.main.enabled == true then
                .name + ",cnpg"
            else
                empty
            end,
            if .config.global.stopAll == true then
                .name + ",stopAll-on"
            elif .config.global.stopAll == false then
                .name + ",stopAll-off"
            else
                empty
            end,
            if .config.global.ixChartContext.isStopped == true then
                .name + ",isStopped-on"
            elif .config.global.ixChartContext.isStopped == false then
                .name + ",isStopped-off"
            else
                empty
            end
            | select(length > 0)
        '
    }

    # Define a function to wait for a free slot in the semaphore
    wait_for_slot() {
        while true; do
            # Count the number of background jobs
            job_count=$(jobs -p | wc -l)

            # Check if there's a free slot
            if [[ $job_count -lt 5 ]]; then
                break
            fi

            # Wait for a short period before checking again
            sleep 0.1
        done
    }

    # Check if an array was passed as an argument
    if [ $# -eq 0 ]; then
        # Define the app names array using the command
        mapfile -t app_names < <(cli -m csv -c 'app chart_release query name' | tail -n +2 | sort | tr -d " \t\r" | awk 'NF')
    else
        # Use the passed array
        app_names=("$@")
    fi

    # Process the app names with a maximum of 5 concurrent processes
    for app_name in "${app_names[@]}"; do
        wait_for_slot
        process_app_name "$app_name" &
    done

    # Wait for any remaining jobs to finish
    wait
}
