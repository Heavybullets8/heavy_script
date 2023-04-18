#!/bin/bash


self_update_handler() {
    local args=("$@")
    declare -x self_update
    declare -x major_self_update
    declare -x no_self_update
    declare -x no_config
    local SELFUPDATE__SELFUPDATE__always
    local SELFUPDATE__SELFUPDATE__when_updating
    local SELFUPDATE__SELFUPDATE__major

    # Check if "self-update" is the first argument and the second argument is a help option
    # heavyscript self-update --help/-h
    if [[ $self_update == true ]] && [[ "${args[0]}" =~ ^(--help|-h)$ ]]; then
        self_update_help
        exit
    fi

    if [[ $no_config == false ]]; then
        read_ini "config.ini" --prefix SELFUPDATE

        # Check if always or when_updating is set to true in the config file
        if { [[ "${SELFUPDATE__SELFUPDATE__always}" == "true" ]] || 
        { [[ "${SELFUPDATE__SELFUPDATE__when_updating}" == "true" ]] && [[ "${args[0]}" == "update" ]]; }; }; then
            self_update=true
        fi

        if [[ "${SELFUPDATE__SELFUPDATE__major}" == "true" ]]; then
            major_self_update=true
        fi
    fi

    # Update the script if --self-update/self-update/-U is passed
    # dont update if --no-self-update is passed
    if $self_update; then
        self_update 
    fi
}
export -f self_update_handler