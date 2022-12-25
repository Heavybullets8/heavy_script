#!/bin/bash


args=("$@")


choose_branch() {
    clear -x
    echo "Pulling git information.."

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
    latest_tag=$(git describe --tags --abbrev=0)

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
}





self_update() {

echo "🅂 🄴 🄻 🄵"
echo "🅄 🄿 🄳 🄰 🅃 🄴"
git fetch --tags &>/dev/null
git reset --hard &>/dev/null

# Check if using a tag or branch
if ! [[ "$hs_version" =~ v\d+\.\d+\.\d+ ]]; then
    # Check for updates on the main branch
    updates=$(git log HEAD..origin/"$hs_version" --oneline)
    # Check if there are any updates available
    if [[ -n "$updates" ]]; then
        # Perform a git pull operation to update the branch to the latest commit
        if ! git pull --force --quiet; then
            # The git pull operation failed, print an error message and exit
            echo "Failed to merge commits from: $hs_version."
            exit 1
        fi
        echo "Merged new commits from: $hs_version."
    else
        echo "No new commits on: $hs_version."
    fi
# The current version is a tag, check if there is a newer tag available
else
    latest_ver=$(git describe --tags "$(git rev-list --tags --max-count=1)")
    if  [[ "$hs_version" != "$latest_ver" ]] ; then
        echo "Found a new version of HeavyScript, updating myself..."
        git checkout "$latest_ver" &>/dev/null 
        echo "Updating from: $hs_version"
        echo "Updating To: $latest_ver"
        echo "Changelog:"
        curl --silent "https://api.github.com/repos/HeavyBullets8/heavy_script/releases/latest" | jq -r .body
        echo 
    else 
        echo "HeavyScript is already the latest version:"
        echo -e "$hs_version\n\n"
    fi
fi


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

}
export -f self_update