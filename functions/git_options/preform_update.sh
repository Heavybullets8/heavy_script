#!/bin/bash


update_func(){
    # Check if using a tag or branch
    if ! [[ "$hs_version" =~ v[[:digit:]]+\.[[:digit:]]+\.[[:digit:]]+ ]]; then
        # Check for updates on the main branch
        updates=$(git log HEAD..origin/"$hs_version" --oneline)
        # Check if there are any updates available
        if [[ -n "$updates" ]]; then
            # Perform a git pull operation to update the branch to the latest commit
            if git pull --force --quiet; then
                echo "Merged new commits from: $hs_version."
                return 111
            else
                # The git pull operation failed, print an error message and exit
                echo "Failed to merge commits from: $hs_version."
                echo "If this issue persists, please ensure the branch exists and is not protected."
                echo "If it does not exist, please change to a different branch or tag from the menu."
            fi
        else
            echo -e "No new commits on: $hs_version.\n\n"
        fi
    # The current version is a tag, check if there is a newer tag available
    else
        latest_tag=$(git describe --tags "$(git rev-list --tags --max-count=1)")
        if  [[ "$hs_version" != "$latest_tag" ]] ; then
            echo "Found a new version of HeavyScript, updating myself..."
            git checkout --force "$latest_tag" &>/dev/null 
            echo "Updating from: $hs_version"
            echo "Updating To: $latest_tag"
            echo "Changelog:"
            curl --silent "https://api.github.com/repos/HeavyBullets8/heavy_script/releases/latest" | jq -r .body
            echo 
            return 111
        else 
            echo "HeavyScript is already the latest version:"
            echo -e "$hs_version\n\n"
        fi
    fi
}
export -f update_func