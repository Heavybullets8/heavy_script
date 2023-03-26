#!/bin/bash


self_update() {
    echo "🅂 🄴 🄻 🄵"
    echo "🅄 🄿 🄳 🄰 🅃 🄴"
    git reset --hard &>/dev/null
    
    # Fetch all branches and tags from the remote
    git fetch --all &>/dev/null

    if ! [[ "$hs_version" =~ v[[:digit:]]+\.[[:digit:]]+\.[[:digit:]]+ ]]; then
        # Get the name of the current local branch
        branch=$(git symbolic-ref --short HEAD)

        # Check if the current local branch exists
        if ! git ls-remote --exit-code --heads origin "$branch" >/dev/null 2>&1; then
            # If the current local branch does not exist, switch to the latest tag
            latest_tag=$(git describe --tags "$(git rev-list --tags --max-count=1)")
            echo "$branch does not exist, switching to the latest tag: $latest_tag"
            git checkout --force "$latest_tag" &>/dev/null
            switched=true
            echo
        fi
    fi

    if [[ $switched != true ]]; then
        update_func
        if [[ $? == 111 ]]; then
            updated=true
        fi
    fi

    echo "${args[@]}"

    # Unset the self-update argument
    for i in "${!args[@]}"; do
        if [[ "${args[$i]}" == "self-update" ]]; then
            unset "args[$i]"
            break
        fi
    done

    echo "${args[@]}"

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