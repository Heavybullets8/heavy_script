#!/bin/bash


args=("$@")
self_update() {

git fetch --tags &>/dev/null
git reset --hard &>/dev/null
latest_ver=$(git describe --tags "$(git rev-list --tags --max-count=1)")
echo "🅂 🄴 🄻 🄵"
echo "🅄 🄿 🄳 🄰 🅃 🄴"
if  [[ "$hs_version" != "$latest_ver" ]] ; then
    echo "Found a new version of HeavyScript, updating myself..."
    git checkout "$latest_ver" &>/dev/null 
    count=0
    for i in "${args[@]}"
    do
        [[ "$i" == "--self-update" ]] && unset "args[$count]" && break
        ((count++))
    done
    echo "Updating from: $hs_version"
    echo "Updating To: $latest_ver"
    echo "Changelog:"
    curl --silent "https://api.github.com/repos/HeavyBullets8/heavy_script/releases/latest" | jq -r .body
    echo 
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