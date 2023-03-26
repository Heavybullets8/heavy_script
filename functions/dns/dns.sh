#!/bin/bash


dns(){
    if [[ $verbose == true ]];then
        dns_verbose
    else
        dns_non_verbose
    fi
}