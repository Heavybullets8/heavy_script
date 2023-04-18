#!/bin/bash

remove_self_update_args() {
    local index
    for ((index = 0; index < ${#args[@]}; index++)); do
        if [[ "${args[index]}" =~ ^(--)?self-update$ || "${args[index]}" == "-U" ]]; then
            self_update=true
            from_cli=true
            unset 'args[index]'
            args=("${args[@]}")
        fi
    done
}

remove_no_self_update_args() {
    local index
    for ((index = 0; index < ${#args[@]}; index++)); do
        if [[ "${args[index]}" == "--no-self-update" ]]; then
            no_self_update=true
            unset 'args[index]'
            args=("${args[@]}")
        fi
    done
}

remove_force_update_args() {
    local index
    for ((index = 0; index < ${#args[@]}; index++)); do
        if [[ "${args[index]}" == "--major" ]]; then
            major_self_update=true
            unset 'args[index]'
            args=("${args[@]}")
        fi
    done
}

remove_no_config_args() {
    local index
    for ((index = 0; index < ${#args[@]}; index++)); do
        if [[ "${args[index]}" == "--no-config" ]]; then
            no_config=true
            unset 'args[index]'
            args=("${args[@]}")
        fi
    done
}

