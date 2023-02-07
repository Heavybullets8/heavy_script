#!/bin/bash


script_create(){
    while true 
    do
        clear -x
        title
        echo -e "${bold}Choose Your Update Type${reset}"
        echo -e "${bold}-----------------------${reset}"
        echo -e "1) -U | Update all applications, ignores versions"
        echo -e "2) -u | Update all applications, does not update Major releases"
        echo
        echo -e "0) Exit"
        echo
        read -rt 120 -p "Type the Number or Flag: " current_selection || { echo -e "${red}\nFailed to make a selection in time${reset}" ; exit; }
        case $current_selection in
            0 | [Ee][Xx][Ii][Tt])
                echo -e "Exiting.."
                exit
                ;;
            1 | 2 | -U | -u)
                if [[ $current_selection == 1 ]] ;then
                    current_selection='-U'
                elif [[ $current_selection == 2 ]] ;then
                    current_selection='-u'
                fi

                while true
                do
                    echo -e "\nHow many applications do you want updating at the same time?"
                    read -rt 120 -p "Please type an integer greater than 0: " up_async || { echo -e "${red}\nFailed to make a selection in time${reset}" ; exit; }

                    case $up_async in
                        "" | *[!0-9]*)
                            echo -e "${red}Error: \"$up_async\" is invalid, it needs to be an integer${reset}"
                            echo -e "${red}NOT adding it to the list${reset}"
                            sleep 3
                            continue
                            ;;
                        0)
                            echo -e "${red}Error: \"$up_async\" is less than 1${reset}"
                            echo -e "${red}NOT adding it to the list${reset}"
                            sleep 3
                            continue
                            ;;
                        *)
                            update_selection+=("$current_selection" "$up_async")
                            break
                            ;;
                    esac
                done
                break
                ;;
            *)
                echo -e "${red}$current_selection was not an option, try again${reset}"
                sleep 3
                continue
                ;;
        esac
    done
    while true 
    do
        clear -x
        title
        echo -e "${bold}Update Options${reset}"
        echo -e "${bold}--------------${reset}"
        echo -e "1) -r | Roll-back applications if they fail to update"
        echo -e "2) -i | Add application to ignore list"
        echo -e "3) -S | Shutdown applications prior to updating"
        echo -e "4) -v | verbose output"
        echo -e "5) -t | Set a custom timeout in seconds when checking if either an App or Mountpoint correctly Started, Stopped or (un)Mounted. Defaults to 500 seconds"
        echo
        echo -e "${bold}Additional Options${reset}"
        echo -e "${bold}------------------${reset}"
        echo -e "6) -b | Back-up your ix-applications dataset"
        echo -e "7) -s | sync catalog"
        echo -e "8) -p | Prune unused/old docker images"
        echo -e "9) --ignore-img   | Ignore container image updates"
        echo -e "10) --self-update | Updates HeavyScript prior to running any other commands"
        echo
        echo -e "88) Undo"
        echo -e "99) Remove ALL Options"
        echo -e "00) Proceed with update"
        echo 
        echo -e "0) Exit"
        echo 
        echo -e "${bold}Current Choices${reset}"
        echo -e "${bold}---------------${reset}"
        echo -e "${blue}bash heavy_script.sh ${update_selection[*]} ${reset}"
        echo
        read -rt 600 -p "Type the Number or Flag: " current_selection || { echo -e "${red}\nFailed to make a selection in time${reset}" ; exit; }
        case $current_selection in
            0 | [Ee][Xx][Ii][Tt])
                echo -e "Exiting.."
                exit
                ;;
            00)
                clear -x
                echo -e "${blue}Running \"bash heavy_script.sh ${update_selection[*]}\" ${reset}"
                echo
                exec bash "$script_name" "${update_selection[@]}"
                exit
                ;;
            1 | -r)
                option="-r"
                ;;
            2 | -i)
                read -rt 120 -p "What is the name of the application we should ignore?: " up_ignore || { echo -e "${red}\nFailed to make a selection in time${reset}" ; exit; }
                if ! [[ $up_ignore =~ ^[a-zA-Z]([-a-zA-Z0-9]*[a-zA-Z0-9])?$ ]]; then
                    echo -e "${red}Error: \"$up_ignore\" is not a possible option for an application name${reset}"
                    sleep 3
                    continue
                fi
                update_selection+=("-i" "$up_ignore")
                continue
                ;;
            3 | -S)
                option="-S"
                ;;
            4 | -v)
                option="-v"
                ;;
            5 | -t)
                echo -e "What do you want your timeout to be?"
                read -rt 120 -p "Please type an integer: " up_timeout || { echo -e "${red}\nFailed to make a selection in time${reset}" ; exit; }
                if ! [[ $up_timeout =~ ^[0-9]+$ ]]; then
                    echo -e "${red}Error: \"$up_timeout\" is invalid, it needs to be an integer\nNOT adding it to the list${reset}"
                    sleep 3
                    continue
                fi
                option="-t"
                value="$up_timeout"
                ;;
            6 | -b)
                echo -e "Up to how many backups should we keep?"
                read -rt 120 -p "Please type an integer: " up_backups || { echo -e "${red}\nFailed to make a selection in time${reset}" ; exit; }
                if ! [[ $up_backups =~ ^[0-9]+$ ]]; then
                    echo -e "${red}Error: \"$up_backups\" is invalid, it needs to be an integer\nNOT adding it to the list${reset}"
                    sleep 3
                    continue
                fi
                if [[ $up_backups == 0 ]]; then
                    echo -e "${red}Error: Number of backups cannot be 0\nNOT adding it to the list${reset}"
                    sleep 3
                    continue
                fi
                option="-b"
                value="$up_backups"
                ;;
            7 | -s)
                option="-s"
                ;;
            8 | -p)
                option="-p"
                ;;
            9 | --ignore-img )
                option="--ignore-img"    
                ;;
            10 | --self-update )
                option="--self-update"     
                ;;
            88)
                # Check if the array has less than or equal to 2 elements
                if [[ ${#update_selection[@]} -eq 2 ]]; then
                    echo -e "${red}Error: You cannot remove the update option and the number of updates${reset}"
                    sleep 3 
                    continue
                fi

                # Initialize a flag to track if we have found a hyphenated element
                found_hyphenated=0

                # Loop through the array in reverse order
                for ((i=${#update_selection[@]}-1; i>=0; i--)); do
                    # Check if the current element is hyphenated
                    if [[ ${update_selection[i]} =~ ^- ]]; then
                        # Set the flag to indicate that we have found a hyphenated element
                        found_hyphenated=1
                    fi
                    # Unset the current element
                    unset "update_selection[$i]"

                    # If we have found a hyphenated element, unset the current element
                    if [[ $found_hyphenated -eq 1 ]]; then
                        # Break out of the loop
                        break
                    fi
                done

                # Reindex the array
                update_selection=( "${update_selection[@]}" )
                continue
                ;;
            99)
                count=2
                for i in "${update_selection[@]:2}"
                do
                    unset "update_selection[$count]"
                    ((count++))
                done
                continue
                ;;
            *)
                echo -e "${red}\"$current_selection\" was not an option, try again${reset}"
                sleep 3
                continue 
                ;;
        esac
        if [[ -n "$option" ]]; then
            # Check if the option is already in the array
            add_option_to_array "${update_selection[@]}" "$option"
            unset option
            unset value
        fi

    done
}
export -f script_create


add_option_to_array() {
    # Check if the option is already in the array
    if printf '%s\0' "${update_selection[@]}" | grep -Fxqz -- "$option"; then
        echo -e "${red}$option is already in the array, skipping${reset}"
        sleep 3
        return
    fi

    # Trim leading and trailing whitespace from the option
    option="${option#"${option%%[![:space:]]*}"}"
    option="${option%"${option##*[![:space:]]}"}"

    # Add the option to the array
    if [[ -n "$value" ]]; then
        update_selection+=("$option" "$value")
    else
        update_selection+=("$option")
    fi
}

