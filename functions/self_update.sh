#!/bin/bash


args=("$@")


choose_branch() {
    clear -x
    echo "Pulling git information.."

    # Fetch all branches and tags from the remote
    git fetch --all &>/dev/null

    # Use git ls-remote to list the available branches
    options=$(git ls-remote --heads)

    # Extract the branch names into an array
    branch_names=()
    while read -r line; do
        # Split the line into fields using the tab character as a delimiter
        IFS=$'\t' read -r _ refname _ <<< "$line"
        # Check if the refname starts with "refs/heads/"
        if [[ $refname == refs/heads/* ]]; then
            # This is a branch, add it to the branch_names array
            branch_names+=("${refname#refs/heads/}")
        fi
    done <<< "$options"

    # Sort the array alphabetically
    mapfile -t branch_names < <(printf '%s\n' "${branch_names[@]}" | sort)

    # Get the name of the latest tag
    latest_tag=$(git describe --tags "$(git rev-list --tags --max-count=1)")

    clear -x
    title
    # Display a menu to the user, including the option to choose the latest tag
    PS3="Choose a branch or the latest tag: "
    select choice in "${branch_names[@]}" "Latest Tag ($latest_tag)"; do
        if [[ -n $choice ]]; then
            # The user made a selection, check if they chose the latest tag
            if [[ $choice == "Latest Tag ($latest_tag)" ]]; then
                # The user chose the latest tag, check it out using git checkout
                git config --local advice.detachedHead false
                git checkout --force "$latest_tag"
                echo "You chose the latest tag: $latest_tag"
                break
            else
                git reset --hard &>/dev/null
                # The user chose a branch, check it out using git checkout
                git checkout --force "$choice"
                echo "You chose $choice"
                git pull --force --quiet
                break
            fi
        else
            # The user entered an invalid selection, display an error message and show the menu again
            echo "Invalid selection. Please try again."
        fi
    done
    chmod +x "$script_name" ; chmod +x "$script_path"/bin/heavyscript 2>/dev/null
}


update_func(){
    # Check if using a tag or branch
    if ! [[ "$hs_version" =~ v[[:digit:]]+\.[[:digit:]]+\.[[:digit:]]+ ]]; then
        git fetch &>/dev/null
        # Check for updates on the main branch
        updates=$(git log HEAD..origin/"$hs_version" --oneline)
        # Check if there are any updates available
        if [[ -n "$updates" ]]; then
            # Perform a git pull operation to update the branch to the latest commit
            if git pull --force --quiet; then
                echo "Merged new commits from: $hs_version."
                updated=true
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
        git fetch --tags &>/dev/null
        latest_tag=$(git describe --tags "$(git rev-list --tags --max-count=1)")
        if  [[ "$hs_version" != "$latest_tag" ]] ; then
            echo "Found a new version of HeavyScript, updating myself..."
            git checkout --force "$latest_tag" &>/dev/null 
            echo "Updating from: $hs_version"
            echo "Updating To: $latest_tag"
            echo "Changelog:"
            curl --silent "https://api.github.com/repos/HeavyBullets8/heavy_script/releases/latest" | jq -r .body
            echo 
            updated=true
        else 
            echo "HeavyScript is already the latest version:"
            echo -e "$hs_version\n\n"
        fi
    fi

    if [[ $updated == true ]]; then
        return 111
    else
        return 100
    fi

}
export -f update_func


self_update() {
    echo "🅂 🄴 🄻 🄵"
    echo "🅄 🄿 🄳 🄰 🅃 🄴"
    git reset --hard &>/dev/null

    if ! [[ "$hs_version" =~ v[[:digit:]]+\.[[:digit:]]+\.[[:digit:]]+ ]]; then
        # Get the name of the current local branch
        branch=$(git symbolic-ref --short HEAD)

        # Check if the current local branch exists
        if ! git rev-parse --verify "$branch" >/dev/null 2>&1; then
            echo "The current branch does not exist, switching to the latest tag.."
            # If the current local branch does not exist, switch to the latest tag
            latest_tag=$(git describe --tags "$(git rev-list --tags --max-count=1)")
            git checkout --force "$latest_tag" &>/dev/null
            switched=true
        fi
    fi

    if [[ $switched != true ]]; then
        update_func
        if [[ $? == 111 ]]; then
            updated=true
        fi
        echo "$?"
    fi

    # Unset the self-update argument
    for i in "${!args[@]}"; do
        if [[ "${args[$i]}" == "--self-update" ]]; then
            unset "args[$i]"
            break
        fi
    done

    chmod +x "$script_name" ; chmod +x "$script_path"/bin/heavyscript 2>/dev/null

    # Check if there are any arguments left
    if [[ -z ${args[*]} ]]; then
        echo -e "No more arguments, exiting..\n\n" && exit
    fi
    # Check if the script was updated, and if so, run the new version
    if [[ "$updated" == true ]]; then
        echo -e "Running the new version...\n\n"
        sleep 5
        exec bash "$script_name" "${args[@]}"
        # Now exit this old instance
        exit
    fi

}
export -f self_update
