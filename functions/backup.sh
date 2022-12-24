#!/bin/bash


backup(){
echo_backup+=("🄱 🄰 🄲 🄺 🅄 🄿 🅂")
echo_backup+=("Number of backups was set to $number_of_backups")

# Get current date and time in a specific format
current_date_time=$(date '+%Y_%m_%d_%H_%M_%S')
: ${backup_prefix:=HeavyScript}
backup_name="${backup_prefix}_${current_date_time}"

# Create a new backup with the current date and time as the name
if [[ "$verbose" == "true" ]]; then
  cli -c "app kubernetes backup_chart_releases backup_name=\"$backup_name\"" &> /dev/null
  echo_backup+=("$backup_name")
else
  echo_backup+=("\nNew Backup Name: ${backup_name}")
  cli -c "app kubernetes backup_chart_releases backup_name=\"$backup_name\"" | tail -n 1 &> /dev/null
  echo_backup+=("$backup_name")
fi

# Get a list of backups sorted by name in descending order
mapfile -t list_backups < <(cli -c 'app kubernetes list_backups' | grep -E "HeavyScript_|TrueTool_" | sort -t '_' -Vr -k2,7 | awk -F '|'  '{print $2}'| tr -d " \t\r")

# If there are more backups than the allowed number, delete the oldest ones
if [[  ${#list_backups[@]}  -gt  "$number_of_backups" ]]; then
  echo_backup+=("\nDeleted the oldest backup(s) for exceeding limit:")
  overflow=$(( ${#list_backups[@]} - "$number_of_backups" ))
  mapfile -t list_overflow < <(cli -c 'app kubernetes list_backups' | grep -E "HeavyScript_|TrueTool_"  | sort -t '_' -V -k2,7 | awk -F '|'  '{print $2}'| tr -d " \t\r" | head -n "$overflow")
  for i in "${list_overflow[@]}"; do
    cli -c "app kubernetes delete_backup backup_name=\"$i\"" &> /dev/null || echo_backup+=("Failed to delete $i")
    echo_backup+=("$i")
  done
fi


#Dump the echo_array, ensures all output is in a neat order. 
for i in "${echo_backup[@]}"
do
    echo -e "$i"
done
echo
echo
}
export -f backup


deleteBackup(){
clear -x && echo "pulling all restore points.."
# shellcheck disable=SC2178
list_backups=$(cli -c 'app kubernetes list_backups' | sort -t '_' -Vr -k2,7 | tr -d " \t\r"  | awk -F '|'  '{print $2}' | nl -s ") " | column -t)
# shellcheck disable=SC2128
if [[ -z "$list_backups" ]]; then
    echo "No restore points available"
    exit
fi

#Select a restore point
while true
do
    clear -x
    title
    echo -e "Choose a Restore Point to Delete\nThese may be out of order if they are not HeavyScript backups"
    echo "$list_backups"
    echo
    echo "0)  Exit"
    read -rt 240 -p "Please type a number: " selection || { echo -e "\nFailed to make a selection in time" ; exit; }
    restore_point=$(echo "$list_backups" | grep ^"$selection)" | awk '{print $2}')
    if [[ $selection == 0 ]]; then
        echo "Exiting.." 
        exit
    elif [[ -z "$selection" ]]; then 
        echo "Your selection cannot be empty"
        sleep 3
        continue
    elif [[ -z "$restore_point" ]]; then
        echo "Invalid Selection: $selection, was not an option"
        sleep 3
        continue
    fi
    break # Break out of the loop if all of the If statement checks above are untrue
done

#Confirm deletion
while true
do
    clear -x
    echo -e "WARNING:\nYou CANNOT go back after deleting your restore point" 
    echo -e "\n\nYou have chosen:\n$restore_point\n\n"
    read -rt 120 -p "Would you like to proceed with deletion? (y/N): " yesno  || { echo -e "\nFailed to make a selection in time" ; exit; }
    case $yesno in
        [Yy] | [Yy][Ee][Ss])
            echo -e "\nDeleting $restore_point"
            cli -c 'app kubernetes delete_backup backup_name=''"'"$restore_point"'"' &>/dev/null || { echo "Failed to delete backup.."; exit; }
            echo "Sucessfully deleted"
            break
            ;;
        [Nn] | [Nn][Oo])
            echo "Exiting"
            exit
            ;;
        *)
            echo "That was not an option, try again"
            sleep 3
            continue
            ;;
    esac
done

#Check if there are more backups to delete
while true
do
    read -rt 120 -p "Delete more backups? (y/N): " yesno || { echo -e "\nFailed to make a selection in time" ; exit; }
    case $yesno in
        [Yy] | [Yy][Ee][Ss])
            break
            ;;
        [Nn] | [Nn][Oo])
            exit
            ;;
        *)
            echo "$yesno was not an option, try again" 
            sleep 2
            continue
            ;;

    esac

done
}
export -f deleteBackup


restore(){
clear -x && echo "pulling restore points.."
list_backups=$(cli -c 'app kubernetes list_backups' | tr -d " \t\r" | sed '1d;$d')

# heavyscript backups
mapfile -t hs_tt_backups < <(echo "$list_backups" | grep -E "HeavyScript_|Truetool_" | sort -t '_' -Vr -k2,7 | awk -F '|'  '{print $2}')
# system backups
mapfile -t system_backups < <(echo "$list_backups" | grep "system-update--" | sort -t '-' -Vr -k3,5 |  awk -F '|'  '{print $2}')
# other backups
mapfile -t other_backups < <(echo "$list_backups" | grep -v -E "HeavyScript_|Truetool_|system-update--" | sort -t '-' -Vr -k3,5 | awk -F '|'  '{print $2}')


#Check if there are any restore points
if [[ ${#hs_tt_backups[@]} -eq 0 ]] && [[ ${#system_backups[@]} -eq 0 ]] && [[ ${#other_backups[@]} -eq 0 ]]; then
    echo "No restore points available"
    exit
fi


# Initialize the restore_points array
restore_points=()

# Append the elements of the hs_tt_backups array
for i in "${hs_tt_backups[@]}"; do
    restore_points+=("$i")
done

# Append the elements of the system_backups array
for i in "${system_backups[@]}"; do
    restore_points+=("$i")
done

# Append the elements of the other_backups array
for i in "${other_backups[@]}"; do
    restore_points+=("$i")
done


# Add line numbers to the array elements
for i in "${!restore_points[@]}"; do
  restore_points[i]="$((i+1))) ${restore_points[i]}"
done



#select a restore point
count=1
while true
do
    clear -x
    title
    echo "Choose a Restore Point"
    echo

    {
    if [[ ${#hs_tt_backups[@]} -gt 0 ]]; then
        echo "$(tput bold)# HeavyScript/Truetool_Backups$(tput sgr0)"
        # Print the HeavyScript and Truetool backups with numbers
        for ((i=0; i<${#hs_tt_backups[@]}; i++)); do
        echo "$count) ${hs_tt_backups[i]}"
        ((count++))
        done
    fi


    # Check if the system backups array is non-empty
    if [[ ${#system_backups[@]} -gt 0 ]]; then
        echo -e "\n$(tput bold)# System_Backups$(tput sgr0)"
        # Print the system backups with numbers
        for ((i=0; i<${#system_backups[@]}; i++)); do
        echo "$count) ${system_backups[i]}"
        ((count++))
        done
    fi


    # Check if the other backups array is non-empty
    if [[ ${#other_backups[@]} -gt 0 ]]; then
        echo -e "\n$(tput bold)# Other_Backups$(tput sgr0)"
        # Print the other backups with numbers
        for ((i=0; i<${#other_backups[@]}; i++)); do
        echo "$count) ${other_backups[i]}"
        ((count++))
        done 
    fi
    } | column -t -L

    echo
    echo "0)  Exit"
    # Prompt the user to select a restore point
    read -rt 240 -p "Please type a number: " selection || { echo -e "\nFailed to make a selection in time" ; exit; }

    # Check if the user wants to exit
    if [[ $selection == 0 ]]; then
        echo "Exiting.." 
        exit
    # Check if the user's input is empty
    elif [[ -z "$selection" ]]; then 
        echo "Your selection cannot be empty"
        sleep 3
        continue
    else
        # Check if the user's selection is a valid option
        found=0
        for point in "${restore_points[@]}"; do
            if grep -q "$selection)" <<< "$point"; then
                found=1
                break
            fi
        done

        # If the user's selection is not a valid option, inform them and prompt them to try again
        if [[ $found -eq 0 ]]; then
            echo "Invalid Selection: $selection, was not an option"
            sleep 3
            continue
        fi
        # Extract the restore point from the array
        restore_point=${restore_points[$((selection-1))]#*[0-9]) }
    fi
    # Break out of the loop
    break
done




## Check to see if empty PVC data is present in any of the applications ##

# Find all pv_info.json files two subfolders deep with the restore point name
pool=$(cli -c 'app kubernetes config' | grep -E "pool\s\|" | awk -F '|' '{print $3}' | tr -d " \t\n\r")
files=$(find "$(find /mnt/"$pool"/ix-applications/backups -maxdepth 0 )" -name pv_info.json | grep "$restore_point")

# Iterate over the list of files
for file in $files; do
    # Check if the file only contains {} subfolders
    contents=$(cat "$file")
    if [[ "$contents" == '{}' ]]; then
        # Print the file if it meets the criterion
        file=$(echo "$file" | awk -F '/' '{print $7}')
        borked_array+=("${file}")
    fi
done


# Grab applications that are supposed to have PVC data
mapfile -t apps_with_pvc < <(k3s kubectl get pvc -A | sort -u | awk '{print $1 "\t" $2 "\t" $4}' | sed "s/^0/ /" | awk '{print $1}' | cut -c 4-)


# Iterate over the list of applications with empty PVC data
# Unset the application if it is not supposed to have PVC data
index=0
for app in "${borked_array[@]}"; do
    if ! printf '%s\0' "${apps_with_pvc[@]}" | grep -iFxqz "${app}" ; then
        unset "borked_array[$index]"
    else
        borked=True
    fi
    ((index++))
done



# If there is still empty PVC data, exit
if [[ $borked == True ]]; then
    echo "Warning!:"
    echo "The following applications have empty PVC data:"
    for app in "${borked_array[@]}"; do
        echo -e "$app"
    done
    echo "We have no choice but to exit"
    echo "If you were to restore, you would lose all of your application data"
    echo "If you are on Bluefin version: 22.12.0, and have not yet ran the patch, you will need to run it"
    echo "Afterwards you will be able to create backups and restore them"
    echo "This is a known ix-systems bug, and has nothing to do with HeavyScript"
    exit
fi


# Only run the check_restore_point_version function if the restore point is a HeavyScript or Truetool backup
if [[ $restore_point =~ "HeavyScript_" || $restore_point =~ "Truetool_" ]]; then
    check_restore_point_version
fi


#Confirm restore
while true
do
    clear -x
    echo -e "WARNING:\nThis is NOT guranteed to work\nThis is ONLY supposed to be used as a LAST RESORT\nConsider rolling back your applications instead if possible"
    echo -e "\n\nYou have chosen:\n$restore_point\n\n"
    read -rt 120 -p "Would you like to proceed with restore? (y/N): " yesno || { echo -e "\nFailed to make a selection in time" ; exit; }
    case $yesno in
        [Yy] | [Yy][Ee][Ss])
            pool=$(cli -c 'app kubernetes config' | grep -E "pool\s\|" | awk -F '|' '{print $3}' | tr -d " \t\n\r")

            # Set mountpoints to legacy prior to restore, ensures correct properties for the are set
            echo -e "\nSetting correct ZFS properties for application volumes.."
            for pvc in $(zfs list -t filesystem -r "$pool"/ix-applications/releases -o name -H | grep "volumes/pvc")
            do
                if zfs set mountpoint=legacy "$pvc"; then
                    echo "Success for - \"$pvc\""
                else
                    echo "Error: Setting properties for \"$pvc\", failed.."
                fi
            done

            # Ensure readonly is turned off
            if ! zfs set readonly=off "$pool"/ix-applications;then
                echo -e "Error: Failed to set ZFS ReadOnly to \"off\""
                echo -e "After the restore, attempt to run the following command manually:"
                echo "zfs set readonly=off $pool/ix-applications"
            fi

            echo "Finished setting properties.."

            # Beginning snapshot restore
            echo -e "\nStarting restore, this will take a LONG time."
            if ! cli -c 'app kubernetes restore_backup backup_name=''"'"$restore_point"'"'; then
                echo "Restore failed, exiting.."
                exit 1
            fi
            exit
            ;;
        [Nn] | [Nn][Oo])
            echo "Exiting"
            exit
            ;;
        *)
            echo "That was not an option, try again"
            sleep 3
            continue
            ;;
    esac
done

}
export -f restore




check_restore_point_version() {

## Check the restore point, and ensure it is the same version as the current system ##
# Boot Query
boot_query=$(cli -m csv -c 'system bootenv query created,realname')

# Get the date of system version and when it was updated
current_version=$(cli -m csv -c 'system version' | awk -F '-' '{print $3}')
when_updated=$(echo "$boot_query" | grep "$current_version",\
| awk -F ',' '{print $2}' | sed 's/[T|-]/_/g' | sed 's/:/_/g' | awk -F '_' '{print $1 $2 $3 $4 $5}')

# Get the date of the chosen restore point
restore_point_date=$(echo "$restore_point" | awk -F '_' '{print $2 $3 $4 $5 $6}' | tr -d "_")

# Grab previous version
previous_version=$(echo "$boot_query" | sort -nr | grep -A 1 "$current_version," | tail -n 1)

# Compare the dates
while (("$restore_point_date" < "$when_updated" ))
do
    clear -x
    echo "The restore point you have chosen is from an older version of Truenas Scale"
    echo "This is not recommended, as it may cause issues with the system"
    echo "Either that, or your systems date is incorrect.."
    echo
    echo "Current SCALE Information:"
    echo "Version:       $current_version"
    echo "When Updated:  $(echo "$restore_point" | awk -F '_' '{print $2 "-" $3 "-" $4}')"
    echo
    echo "Restore Point SCALE Information:"
    echo "Version:       $(echo "$previous_version" | awk -F ',' '{print $1}')"
    echo "When Updated:  $(echo "$previous_version" | awk -F ',' '{print $2}' | awk -F 'T' '{print $1}')"
    echo
    read -rt 120 -p "Would you like to proceed? (y/N): " yesno || { echo -e "\nFailed to make a selection in time" ; exit; }
        case $yesno in
            [Yy] | [Yy][Ee][Ss])
                echo "Proceeding.."
                sleep 3
                break
                ;;
            [Nn] | [Nn][Oo])
                echo "Exiting"
                exit
                ;;
            *)
                echo "That was not an option, try again"
                sleep 3
                continue
                ;;
        esac
done
}

