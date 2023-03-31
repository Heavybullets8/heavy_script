#!/bin/bash


is_major_update() {
    local current_version="$1"
    local latest_version="$2"

    local current_major_version latest_major_version

    current_major_version="${current_version%%.*}"
    latest_major_version="${latest_version%%.*}"

    if [[ "$latest_major_version" -gt "$current_major_version" ]]; then
        return 0
    else
        return 1
    fi
}


update_branch() {

    updates=$(git log HEAD..origin/"$hs_version" --oneline)
    if [[ -n "$updates" ]]; then
        if git pull --force --quiet; then
            echo "Merged new commits from: $hs_version."
            return 111
        else
            echo "Failed to merge commits from: $hs_version."
            echo "If this issue persists, please ensure the branch exists and is not protected."
            echo "If it does not exist, please change to a different branch or tag from the menu."
        fi
    else
        echo -e "No new commits on: $hs_version.\n\n"
    fi
}


update_tagged_version() {
    local include_major="$1"
    local latest_tag
    latest_tag=$(git describe --tags "$(git rev-list --tags --max-count=1)")

    if [[ "$hs_version" != "$latest_tag" ]]; then
        if [[ "$include_major" == "true" ]] || ! is_major_update "${hs_version#v}" "${latest_tag#v}"; then
            echo "Found a new version of HeavyScript, updating myself..."
            git checkout --force "$latest_tag" &>/dev/null
            echo "Updating from: $hs_version"
            echo "Updating To: $latest_tag"
            echo "Changelog:"
            curl --silent "https://api.github.com/repos/HeavyBullets8/heavy_script/releases/latest" | jq -r .body
            echo
            return 111
        else
            echo "A major update is available: $latest_tag"
            echo "Skipping the update due to major version change."
        fi
    else
        echo "HeavyScript is already the latest version:"
        echo -e "$hs_version\n\n"
    fi
}


update_func() {
    local include_major="$1"
    if ! [[ "$hs_version" =~ v[[:digit:]]+\.[[:digit:]]+\.[[:digit:]]+ ]]; then
        update_branch
    else
        update_tagged_version "$include_major"
    fi

    echo "Include major: $include_major"
}
