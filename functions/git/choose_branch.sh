#!/bin/bash


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