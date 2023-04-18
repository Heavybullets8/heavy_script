#!/bin/bash

remove_self_update_args() {
    index=0
    while [ $index -lt ${#args[@]} ]; do
        if [[ "${args[index]}" =~ ^(--)?self-update$ || "${args[index]}" == "-U" ]]; then
            self_update=true
            args=("${args[@]:0:index}" "${args[@]:index+1}")
        else
            ((index++))
        fi
    done
}

remove_no_self_update_args() {
    index=0
    while [ $index -lt ${#args[@]} ]; do
        if [[ "${args[index]}" == "--no-self-update" ]]; then
            no_self_update=true
            args=("${args[@]:0:index}" "${args[@]:index+1}")
        else
            ((index++))
        fi
    done
}

remove_force_update_args() {
    index=0
    while [ $index -lt ${#args[@]} ]; do
        if [[ "${args[index]}" == "--major" ]]; then
            major_self_update=true
            args=("${args[@]:0:index}" "${args[@]:index+1}")
        else
            ((index++))
        fi
    done
}

remove_no_config_args() {
    index=0
    while [ $index -lt ${#args[@]} ]; do
        if [[ "${args[index]}" == "--no-config" ]]; then
            no_config=true
            args=("${args[@]:0:index}" "${args[@]:index+1}")
        else
            ((index++))
        fi
    done
}
