#!/bin/bash


self_update_handler() {
    local input_args=("$@")
    local menu_toggle=false

    # Check if "self-update" is the first argument and the second argument is a help option
    # heavyscript self-update --help/-h
    if [[ "${input_args[0]}" == "self-update" ]] && [[ "${input_args[1]}" =~ ^(--help|-h)$ ]]; then
        self_update_help
        exit
    fi

    # Toggle the menu if no arguments are passed, the first argument is an empty string, '-', or '--'
    # This is useful for when a user has self-update always set to true in the config file
    if [[ "${#input_args[@]}" -eq 0 || "${input_args[0]}" =~ ^(-{1,2})?$ ]]; then
        menu_toggle=true
    fi

    local args
    # check for --no-config
    if [[ $no_config == false ]]; then
        # Read the config.ini file if --no-config is not passed
        mapfile -t args < <(add_selfupdate_major_from_config "${input_args[@]}")
    fi

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

    # Update the script if --self-update/self-update/-U is passed
    # dont update if --no-self-update is passed
    if $self_update && ! $no_self_update; then
        self_update "$menu_toggle" "$include_major"
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