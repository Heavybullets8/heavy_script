#!/bin/bash

args=("$@")
self_update() {
branch="ignore-file"
git fetch &> /dev/null 
echo "🅂 🄴 🄻 🄵"
echo "🅄 🄿 🄳 🄰 🅃 🄴"
if  git diff --name-only origin/$branch | grep -qs ".sh" ; then
    echo "Found a new version of HeavyScript, updating myself..."
    git reset --hard -q
    git pull --force -q
    count=0
    for i in "${args[@]}"
    do
        [[ "$i" == "--self-update" ]] && unset "args[$count]" && break
        ((count++))
    done
    [[ -z ${args[*]} ]] && echo -e "No more arguments, exiting..\n\n" && exit
    echo -e "Running the new version...\n\n"
    sleep 5
    exec bash "$script_name" "${args[@]}"
    # Now exit this old instance
    exit
else 
    echo -e "HeavyScript is already the latest version\n\n"
fi
}
export -f self_update
