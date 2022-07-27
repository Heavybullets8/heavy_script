#!/bin/bash

args=("$@")
self_update() {
git fetch &> /dev/null 
# TODO: change beta to main once testing is complete
if  git diff --name-only origin/beta | grep -qs ".sh" ; then
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