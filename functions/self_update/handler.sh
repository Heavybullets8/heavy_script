#!/bin/bash


self_update_handler() {
    local input_args=("$@")
    
    # Check if "self-update" is the first argument and the second argument is a help option
    if [[ "${input_args[0]}" == "self-update" ]] && [[ "${input_args[1]}" =~ ^(--help|-h)$ ]]; then
        self_update_help
        exit
    fi

    local args
    mapfile -t args < <(add_selfupdate_major_from_config "${input_args[@]}")

    local self_update=false
    local no_self_update=false
    local include_major=false

    for arg in "${args[@]}"; do
        if [[ "$arg" =~ ^(--)?self-update$ || "$arg" == "-U" ]]; then
            self_update=true
        elif [[ "$arg" == "--no-self-update" ]]; then
            no_self_update=true
            return
        elif [[ "$arg" == "--major" ]]; then
            include_major=true
        fi
    done

    if $self_update && ! $no_self_update; then
        self_update 
    fi
}
export -f self_update_handler



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