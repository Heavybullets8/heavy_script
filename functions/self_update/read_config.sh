#!/bin/bash


add_selfupdate_major_from_config() {
    local input_args=("$@")
    local output_args=("${input_args[@]}")

    # Read the config.ini file
    read_ini "config.ini" --prefix SELFUPDATE

    # Check if always or when_updating is set to true in the config file
    if { [[ "${SELFUPDATE__SELFUPDATE__always}" == "true" ]] || 
       { [[ "${SELFUPDATE__SELFUPDATE__when_updating}" == "true" ]] && [[ "${output_args[0]}" == "update" ]]; }; }; then
        output_args+=("self-update")
    fi

    if [[ "${SELFUPDATE__SELFUPDATE__major}" == "true" ]]; then
        output_args+=("--major")
    fi

    printf "%s\n" "${output_args[@]}"
}

