#!/bin/bash


script_create(){
while true 
do
    clear -x
    title
    echo "Choose Your Update Type"
    echo "-----------------------"
    echo "1) -U | Update all applications, ignores versions"
    echo "2) -u | Update all applications, does not update Major releases"
    echo
    echo "0) Exit"
    echo
    read -rt 120 -p "Type the Number or Flag: " current_selection || { echo -e "\nFailed to make a selection in time" ; exit; }
    case $current_selection in
        0 | [Ee][Xx][Ii][Tt])
            echo "Exiting.."
            exit
            ;;
        1 | -U) 
            while true
            do
                echo -e "\nHow many applications do you want updating at the same time?"
                read -rt 120 -p "Please type an integer greater than 0: " up_async || { echo -e "\nFailed to make a selection in time" ; exit; }

                case $up_async in
                    "" | *[!0-9]*)
                        echo "Error: \"$up_async\" is invalid, it needs to be an integer"
                        echo "NOT adding it to the list"
                        sleep 3
                        continue
                        ;;
                    0)
                        echo "Error: \"$up_async\" is less than 1"
                        echo "NOT adding it to the list"
                        sleep 3
                        continue
                        ;;
                    *)
                        update_selection+=("-U" "$up_async")
                        break
                        ;;
                esac
            done
            break
            ;;
        2 | -u)
            while true
            do
                echo -e "\nHow many applications do you want updating at the same time?"
                read -rt 120 -p "Please type an integer greater than 0: " up_async || { echo -e "\nFailed to make a selection in time" ; exit; }

                case $up_async in
                    "" | *[!0-9]*)
                        echo "Error: \"$up_async\" is invalid, it needs to be an integer"
                        echo "NOT adding it to the list"
                        sleep 3
                        continue
                        ;;
                    0)
                        echo "Error: \"$up_async\" is less than 1"
                        echo "NOT adding it to the list"
                        sleep 3
                        continue
                        ;;
                    *)
                        update_selection+=("-u" "$up_async")
                        break
                        ;;
                esac
            done
            break
            ;;
        *)
            echo "$current_selection was not an option, try again" && sleep 3
            continue
            ;;
    esac
done
while true 
do
    clear -x
    title
    echo "Update Options"
    echo "--------------"
    echo "1) -r | Roll-back applications if they fail to update"
    echo "2) -i | Add application to ignore list"
    echo "3) -S | Shutdown applications prior to updating"
    echo "4) -v | verbose output"
    echo "5) -t | Set a custom timeout in seconds when checking if either an App or Mountpoint correctly Started, Stopped or (un)Mounted. Defaults to 500 seconds"
    echo
    echo "Additional Options"
    echo "------------------"
    echo "6) -b | Back-up your ix-applications dataset"
    echo "7) -s | sync catalog"
    echo "8) -p | Prune unused/old docker images"
    echo "9) --ignore-img   | Ignore container image updates"
    echo "10) --self-update | Updates HeavyScript prior to running any other commands"
    echo
    echo "99) Remove Update Options, Restart"
    echo "00) Done making selections, proceed with update"
    echo 
    echo "0) Exit"
    echo 
    echo "Current Choices"
    echo "---------------"
    echo "bash heavy_script.sh ${update_selection[*]}"
    echo
    read -rt 600 -p "Type the Number or Flag: " current_selection || { echo -e "\nFailed to make a selection in time" ; exit; }
    case $current_selection in
        0 | [Ee][Xx][Ii][Tt])
            echo "Exiting.."
            exit
            ;;
        00)
            clear -x
            echo "Running \"bash heavy_script.sh ${update_selection[*]}\""
            echo
            exec bash "$script_name" "${update_selection[@]}"
            exit
            ;;
        1 | -r)
            option="-r"
            ;;
        2 | -i)
            read -rt 120 -p "What is the name of the application we should ignore?: " up_ignore || { echo -e "\nFailed to make a selection in time" ; exit; }
            ! [[ $up_ignore =~ ^[a-zA-Z]([-a-zA-Z0-9]*[a-zA-Z0-9])?$ ]] && echo -e "Error: \"$up_ignore\" is not a possible option for an application name" && sleep 3 && continue
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
            option="-t"
            add_option_to_array "${update_selection[@]}" "$option"
            echo "What do you want your timeout to be?"
            read -rt 120 -p "Please type an integer: " up_timeout || { echo -e "\nFailed to make a selection in time" ; exit; }
            ! [[ $up_timeout =~ ^[0-9]+$ ]] && echo -e "Error: \"$up_timeout\" is invalid, it needs to be an integer\nNOT adding it to the list" && sleep 3 && continue
            update_selection+=("-t" "$up_timeout")
            continue
            ;;
        6 | -b)
            option="-b"
            add_option_to_array "${update_selection[@]}" "$option"
            echo "Up to how many backups should we keep?"
            read -rt 120 -p "Please type an integer: " up_backups || { echo -e "\nFailed to make a selection in time" ; exit; }
            ! [[ $up_backups =~ ^[0-9]+$ ]] && echo -e "Error: \"$up_backups\" is invalid, it needs to be an integer\nNOT adding it to the list" && sleep 3 && continue
            [[ $up_backups == 0 ]] && echo -e "Error: Number of backups cannot be 0\nNOT adding it to the list" && sleep 3 && continue
            update_selection+=("-b" "$up_backups")
            continue
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
        99)
            count=2
            echo "restarting"
            for i in "${update_selection[@]:2}"
            do
                unset "update_selection[$count]"
                echo "$i removed"
                ((count++))
            done
            sleep 3
            continue
            ;;
        *)
            echo "\"$current_selection\" was not an option, try again" && sleep 3 && continue 
            ;;
    esac
    # Check if the option is already in the array
    add_option_to_array "${update_selection[@]}" "$option"

done
}
export -f script_create


add_option_to_array() {
  # Check if the option is already in the array
  if printf '%s\0' "${update_selection[@]}" | grep -Fxqz -- "$option"; then
    echo "$option is already in the array, skipping"
    sleep 3
    return
  fi

  # Add the option to the array
  update_selection+=("$option")
}

