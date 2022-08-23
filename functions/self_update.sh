#!/bin/bash

args=("$@")
self_update() {
branch="main"
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
    echo "Updating from:"
    echo "$hs_version"
    echo "Updating To:"
    curl --silent "https://api.github.com/repos/HeavyBullets8/heavy_script/releases/latest" | jq -r .tag_name,.body
    [[ -z ${args[*]} ]] && echo -e "No more arguments, exiting..\n\n" && exit
    echo -e "Running the new version...\n\n"
    sleep 5
    exec bash "$script_name" "${args[@]}"
    # Now exit this old instance
    exit
else 
    echo "HeavyScript is already the latest version:"
    echo -e "$hs_version\n\n"
fi
}
export -f self_update
