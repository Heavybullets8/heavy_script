#!/bin/bash

create_backup(){
    retention=$1
    backup_type=$2
    declare timestamp
    timestamp=$(date '+%Y_%m_%d_%H_%M_%S')

    backup_cnpg_databases "$retention" "$timestamp"

    create_snapshot "$retention" "$backup_type" "$timestamp"
}