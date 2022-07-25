#!/bin/bash

args=("$@")

self_update() {
script=$(readlink -f "$0")
script_path=$(dirname "$script")
script_name="heavy_script.sh"
cd "$script_path" || exit
git fetch &> /dev/null 

if  git diff --name-only origin/main | grep -q "$script_name" ; then
    echo "Found a new version of HeavyScript, updating myself..."
    git reset --hard -q
    git pull --force -q
    echo -e "Running the new version...\n"
    count=0
    for i in "${args[@]}"
    do
        [[ "$i" == "--self-update" ]] && unset "args[$count]" && break
        ((count++))
    done
    sleep 5
    exec bash "$script_name" "${args[@]}"

    # Now exit this old instance
    exit
else 
    echo -e "HeavyScript is already the latest version\n"
fi
}
export -f self_update