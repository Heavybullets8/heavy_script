#!/bin/bash

#If no argument is passed, kill the script.
[[ -z "$*" || "-" == "$*" || "--" == "$*"  ]] && echo "This script requires an argument, use --help for help" && exit


help(){
[[ $help == "true" ]] && clear -x
echo "Basic Utilities"
echo "--mount         | Initiates mounting feature, choose between unmounting and mounting PVC data"
echo "--restore       | Opens a menu to restore a \"heavy_script\" backup that was taken on your \"ix-applications\" dataset"
echo "--delete backup | Opens a menu to delete backups on your system"
echo "--dns           | list all of your applications DNS names and their web ports"
echo
echo "Update Options"
echo "-U | Update all applications, ignores versions"
echo "-u | Update all applications, does not update Major releases"
echo "-b | Back-up your ix-applications dataset, specify a number after -b"
echo "-i | Add application to ignore list, one by one, see example below."
echo "-R | THIS OPTION WILL DEPRICATE SOON, USE \"-r\" instead. Roll-back applications if they fail to update"
echo "-r | Roll-back applications if they fail to update"
echo "-S | Shutdown applications prior to updating"
echo "-v | verbose output"
echo "-t | Set a custom timeout in seconds when checking if either an App or Mountpoint correctly Started, Stopped or (un)Mounted. Defaults to 500 seconds"
echo "-s | sync catalog"
echo "-p | Prune unused/old docker images"
echo 
echo "Examples"
echo "bash heavy_script.sh -b 14 -i portainer -i arch -i sonarr -i radarr -t 600 -vrsUp"
echo "bash /mnt/tank/scripts/heavy_script.sh -t 150 --mount"
echo "bash /mnt/tank/scripts/heavy_script.sh --dns"
echo "bash /mnt/tank/scripts/heavy_script.sh --restore"  
echo "bash /mnt/tank/scripts/heavy_script.sh --delete-backup"
echo         
exit
}
export -f help


deleteBackup(){
clear -x && echo "pulling all restore points.."
list_backups=$(cli -c 'app kubernetes list_backups' | sort -t '_' -Vr -k2,7 | tr -d " \t\r"  | awk -F '|'  '{print $2}' | nl | column -t)
clear -x
[[ -z "$list_backups" ]] && echo "No restore points available" && exit || { title; echo -e "Choose a restore point to delete\nThese may be out of order if they are not HeavyScript backups" ;  }
echo "$list_backups" && read -t 600 -p "Please type a number: " selection && restore_point=$(echo "$list_backups" | grep ^"$selection " | awk '{print $2}')
[[ -z "$selection" ]] && echo "Your selection cannot be empty" && exit #Check for valid selection. If none, kill script
[[ -z "$restore_point" ]] && echo "Invalid Selection: $selection, was not an option" && exit #Check for valid selection. If none, kill script
echo -e "\nWARNING:\nYou CANNOT go back after deleting your restore point" || { echo "FAILED"; exit; }
echo -e "\n\nYou have chosen:\n$restore_point\n\nWould you like to continue?"  && echo -e "1  Yes\n2  No" && read -t 120 -p "Please type a number: " yesno || { echo "FAILED"; exit; }
if [[ $yesno == "1" ]]; then
    echo -e "\nDeleting $restore_point" && cli -c 'app kubernetes delete_backup backup_name=''"'"$restore_point"'"' &>/dev/null && echo "Sucessfully deleted" || echo "Deletion Failed"
elif [[ $yesno == "2" ]]; then
    echo "You've chosen NO, killing script."
else
    echo "Invalid Selection"
fi
}
export -f deleteBackup


backup(){
echo -e "\nNumber of backups was set to $number_of_backups"
date=$(date '+%Y_%m_%d_%H_%M_%S')
[[ "$verbose" == "true" ]] && cli -c 'app kubernetes backup_chart_releases backup_name=''"'HeavyScript_"$date"'"'
[[ -z "$verbose" ]] && echo -e "\nNew Backup Name:" && cli -c 'app kubernetes backup_chart_releases backup_name=''"'HeavyScript_"$date"'"' | tail -n 1
mapfile -t list_backups < <(cli -c 'app kubernetes list_backups' | grep "HeavyScript_" | sort -t '_' -Vr -k2,7 | awk -F '|'  '{print $2}'| tr -d " \t\r")
if [[  ${#list_backups[@]}  -gt  "number_of_backups" ]]; then
    echo -e "\nDeleting the oldest backup(s) for exceeding limit:"
    overflow=$(( ${#list_backups[@]} - "$number_of_backups" ))
    mapfile -t list_overflow < <(cli -c 'app kubernetes list_backups' | grep "HeavyScript_"  | sort -t '_' -V -k2,7 | awk -F '|'  '{print $2}'| tr -d " \t\r" | head -n "$overflow")
    for i in "${list_overflow[@]}"
    do
        cli -c 'app kubernetes delete_backup backup_name=''"'"$i"'"' &> /dev/null || echo "Failed to delete $i"
        echo "$i"
    done
fi
}
export -f backup


restore(){
clear -x && echo "pulling restore points.."
list_backups=$(cli -c 'app kubernetes list_backups' | grep "HeavyScript_" | sort -t '_' -Vr -k2,7 | tr -d " \t\r"  | awk -F '|'  '{print $2}' | nl | column -t)
clear -x
[[ -z "$list_backups" ]] && echo "No HeavyScript restore points available" && exit || { title; echo "Choose a restore point" ;  }
echo "$list_backups" && read -t 600 -p "Please type a number: " selection && restore_point=$(echo "$list_backups" | grep ^"$selection " | awk '{print $2}')
[[ -z "$selection" ]] && echo "Your selection cannot be empty" && exit #Check for valid selection. If none, kill script
[[ -z "$restore_point" ]] && echo "Invalid Selection: $selection, was not an option" && exit #Check for valid selection. If none, kill script
echo -e "\nWARNING:\nThis is NOT guranteed to work\nThis is ONLY supposed to be used as a LAST RESORT\nConsider rolling back your applications instead if possible" || { echo "FAILED"; exit; }
echo -e "\n\nYou have chosen:\n$restore_point\n\nWould you like to continue?"  && echo -e "1  Yes\n2  No" && read -t 120 -p "Please type a number: " yesno || { echo "FAILED"; exit; }
if [[ $yesno == "1" ]]; then
    echo -e "\nStarting Backup, this will take a LONG time." && cli -c 'app kubernetes restore_backup backup_name=''"'"$restore_point"'"' || echo "Restore FAILED"
elif [[ $yesno == "2" ]]; then
    echo "You've chosen NO, killing script. Good luck."
else
    echo "Invalid Selection"
fi
}
export -f restore


dns(){
clear -x
echo "Generating DNS Names.."
#ignored dependency pods, No change required
dep_ignore="cron|kube-system|nvidia|svclb|NAME|memcached"

# Pulling pod names
mapfile -t main < <(k3s kubectl get pods -A | grep -Ev "$dep_ignore" | sort)

# Pulling all ports
all_ports=$(k3s kubectl get service -A)

clear -x
count=0
for i in "${main[@]}"
do
    [[ count -le 0 ]] && echo -e "\n" && ((count++))
    appName=$(echo "$i" | awk '{print $2}' | sed 's/-[^-]*-[^-]*$//' | sed 's/-0//')
    ixName=$(echo "$i" | awk '{print $1}')
    port=$(echo "$all_ports" | grep -E "\s$appName\s" | awk '{print $6}' | grep -Eo "^[[:digit:]]+{1}")
    echo -e "$appName.$ixName.svc.cluster.local $port"
done | uniq | nl -b t | sed 's/\s\s\s$/- -------- ----/' | column -t -R 1 -N "#,DNS_Name,Port" -L
}
export -f dns


mount(){
clear -x
title
echo -e "1  Mount\n2  Unmount All" && read -t 600 -p "Please type a number: " selection
[[ -z "$selection" ]] && echo "Your selection cannot be empty" && exit #Check for valid selection. If none, kill script
if [[ $selection == "1" ]]; then
    list=$(k3s kubectl get pvc -A | sort -u | awk '{print NR-1, "\t" $1 "\t" $2 "\t" $4}' | column -t | sed "s/^0/ /")
    echo "$list" && read -t 120 -p "Please type a number: " selection
    [[ -z "$selection" ]] && echo "Your selection cannot be empty" && exit #Check for valid selection. If none, kill script
    app=$(echo -e "$list" | grep ^"$selection " | awk '{print $2}' | cut -c 4- )
    [[ -z "$app" ]] && echo "Invalid Selection: $selection, was not an option" && exit #Check for valid selection. If none, kill script
    pvc=$(echo -e "$list" | grep ^"$selection ")
    status=$(cli -m csv -c 'app chart_release query name,status' | grep -E "^$app\b" | awk -F ',' '{print $2}'| tr -d " \t\n\r")
    if [[ "$status" != "STOPPED" ]]; then
        [[ -z $timeout ]] && echo -e "\nDefault Timeout: 500" && timeout=500 || echo -e "\nCustom Timeout: $timeout"
        SECONDS=0 && echo -e "\nScaling down $app" && midclt call chart.release.scale "$app" '{"replica_count": 0}' &> /dev/null
    else
        echo -e "\n$app is already stopped"
    fi
    while [[ "$SECONDS" -le "$timeout" && "$status" != "STOPPED" ]]
    do
        status=$(cli -m csv -c 'app chart_release query name,status' | grep -E "^$app\b" | awk -F ',' '{print $2}'| tr -d " \t\n\r")
        echo -e "Waiting $((timeout-SECONDS)) more seconds for $app to be STOPPED" && sleep 5
    done
    data_name=$(echo "$pvc" | awk '{print $3}')
    mount=$(echo "$pvc" | awk '{print $4}')
    volume_name=$(echo "$pvc" | awk '{print $4}')
    full_path=$(zfs list | grep "$volume_name" | awk '{print $1}')
    echo -e "\nMounting\n$full_path\nTo\n/mnt/heavyscript/$data_name" && zfs set mountpoint=/heavyscript/"$data_name" "$full_path" && echo -e "Mounted\n\nUnmount with:\nzfs set mountpoint=legacy "$full_path" && rmdir /mnt/heavyscript/"$data_name"\n\nOr use the Unmount All option\n"
    exit
elif [[ $selection == "2" ]]; then
    mapfile -t unmount_array < <(basename -a /mnt/heavyscript/* | sed "s/*//")
    [[ -z $unmount_array ]] && echo "Theres nothing to unmount" && exit
    for i in "${unmount_array[@]}"
    do
        main=$(k3s kubectl get pvc -A | grep -E "\s$i\s" | awk '{print $1, $2, $4}')
        app=$(echo "$main" | awk '{print $1}' | cut -c 4-)
        pvc=$(echo "$main" | awk '{print $3}')
        mapfile -t path < <(find /mnt/*/ix-applications/releases/"$app"/volumes/ -maxdepth 0 | cut -c 6-)
        if [[  "${#path[@]}" -gt 1 ]]; then #if there is another app with the same name on another pool, use the current pools application, since the other instance is probably old, or unused.
            echo "$i is a name used on more than one pool.. attempting to use your current kubernetes apps pool"
            pool=$(cli -c 'app kubernetes config' | grep -E "dataset\s\|" | awk -F '|' '{print $3}' | awk -F '/' '{print $1}' | tr -d " \t\n\r")
            full_path=$(find /mnt/"$pool"/ix-applications/releases/"$app"/volumes/ -maxdepth 0 | cut -c 6-)
            zfs set mountpoint=legacy "$full_path""$pvc" && echo "$i unmounted" && rmdir /mnt/heavyscript/"$i" || echo "failed to unmount $i"
        else
            zfs set mountpoint=legacy "$path""$pvc" && echo "$i unmounted" && rmdir /mnt/heavyscript/"$i" || echo "failed to unmount $i"
        fi
    done
    rmdir /mnt/heavyscript
else
    echo "Invalid selection, \"$selection\" was not an option"
fi
}
export -f mount


sync(){
echo -e "\nSyncing all catalogs, please wait.." && cli -c 'app catalog sync_all' &> /dev/null && echo -e "Catalog sync complete"
}
export -f sync


update_apps(){
mapfile -t array < <(cli -m csv -c 'app chart_release query name,update_available,human_version,human_latest_version,container_images_update_available,status' | grep -E ",true(,|$)" | sort)
[[ -z $array ]] && echo -e "\nThere are no updates available" && return 0 || echo -e "\n${#array[@]} update(s) available"
[[ -z $timeout ]] && echo -e "\nDefault Timeout: 500" && timeout=500 || echo -e "\nCustom Timeout: $timeout"
[[ "$timeout" -le 120 ]] && echo "Warning: Your timeout is set low and may lead to premature rollbacks or skips"
    for i in "${array[@]}"
    do
        app_name=$(echo "$i" | awk -F ',' '{print $1}') #print out first catagory, name.
        old_app_ver=$(echo "$i" | awk -F ',' '{print $4}' | awk -F '_' '{print $1}' | awk -F '.' '{print $1}') #previous/current Application MAJOR Version
        new_app_ver=$(echo "$i" | awk -F ',' '{print $5}' | awk -F '_' '{print $1}' | awk -F '.' '{print $1}') #new Application MAJOR Version
        old_chart_ver=$(echo "$i" | awk -F ',' '{print $4}' | awk -F '_' '{print $2}' | awk -F '.' '{print $1}') # Old Chart MAJOR version
        new_chart_ver=$(echo "$i" | awk -F ',' '{print $5}' | awk -F '_' '{print $2}' | awk -F '.' '{print $1}') # New Chart MAJOR version
        status=$(echo "$i" | awk -F ',' '{print $2}') #status of the app: STOPPED / DEPLOYING / ACTIVE
        startstatus=$status
        diff_app=$(diff <(echo "$old_app_ver") <(echo "$new_app_ver")) #caluclating difference in major app versions
        diff_chart=$(diff <(echo "$old_chart_ver") <(echo "$new_chart_ver")) #caluclating difference in Chart versions
        old_full_ver=$(echo "$i" | awk -F ',' '{print $4}') #Upgraded From
        new_full_ver=$(echo "$i" | awk -F ',' '{print $5}') #Upraded To
        rollback_version=$(echo "$i" | awk -F ',' '{print $4}' | awk -F '_' '{print $2}')
        printf '%s\0' "${ignore[@]}" | grep -iFxqz "${app_name}" && echo -e "\n$app_name\nIgnored, skipping" && continue #If application is on ignore list, skip
            if [[ "$diff_app" == "$diff_chart" || "$update_all_apps" == "true" ]]; then #continue to update
                if [[ $stop_before_update == "true" ]]; then # Check to see if user is using -S or not
                    if [[ "$status" ==  "STOPPED" ]]; then # if status is already stopped, skip while loop
                        echo -e "\n$app_name"
                        [[ "$verbose" == "true" ]] && echo "Updating.."
                        cli -c 'app chart_release upgrade release_name=''"'"$app_name"'"' &> /dev/null && echo -e "Updated\n$old_full_ver\n$new_full_ver" && after_update_actions || echo "FAILED"
                        continue
                    else # if status was not STOPPED, stop the app prior to updating
                        echo -e "\n$app_name"
                        [[ "$verbose" == "true" ]] && echo "Stopping prior to update.."
                        midclt call chart.release.scale "$app_name" '{"replica_count": 0}' &> /dev/null && SECONDS=0 || echo -e "FAILED"
                        while [[ "$status" !=  "STOPPED" ]]
                        do
                            status=$(cli -m csv -c 'app chart_release query name,update_available,human_version,human_latest_version,status' | grep "^$app_name," | awk -F ',' '{print $2}')
                            if [[ "$status"  ==  "STOPPED" ]]; then
                                echo "Stopped"
                                [[ "$verbose" == "true" ]] && echo "Updating.."
                                cli -c 'app chart_release upgrade release_name=''"'"$app_name"'"' &> /dev/null && echo -e "Updated\n$old_full_ver\n$new_full_ver" && after_update_actions || echo "Failed to update"
                                break
                            elif [[ "$SECONDS" -ge "$timeout" ]]; then
                                echo "Error: Run Time($SECONDS) has exceeded Timeout($timeout)"
                                break
                            elif [[ "$status" !=  "STOPPED" ]]; then
                                [[ "$verbose" == "true" ]] && echo "Waiting $((timeout-SECONDS)) more seconds for $app_name to be STOPPED"
                                sleep 10
                                continue
                            fi
                        done
                    fi
                else #user must not be using -S, just update
                    echo -e "\n$app_name"
                    [[ "$verbose" == "true" ]] && echo "Updating.."
                    cli -c 'app chart_release upgrade release_name=''"'"$app_name"'"' &> /dev/null && echo -e "Updated\n$old_full_ver\n$new_full_ver" && after_update_actions || { echo "FAILED"; continue; }
                fi
            else
                echo -e "\n$app_name\nMajor Release, update manually"
                continue
            fi
    done
}
export -f update_apps


after_update_actions(){
SECONDS=0
count=0
if [[ $rollback == "true" ]]; then
    while [[ "0"  !=  "1" ]]
    do
        (( count++ ))
        status=$(cli -m csv -c 'app chart_release query name,update_available,human_version,human_latest_version,status' | grep "^$app_name," | awk -F ',' '{print $2}')
        if [[ "$status"  ==  "ACTIVE" && "$startstatus"  ==  "STOPPED" ]]; then
            [[ "$verbose" == "true" ]] && echo "Returing to STOPPED state.."
            midclt call chart.release.scale "$app_name" '{"replica_count": 0}' &> /dev/null && echo "Stopped"|| echo "FAILED"
            break
        elif [[ "$SECONDS" -ge "$timeout" && "$status"  ==  "DEPLOYING" && "$failed" != "true" ]]; then
            echo -e "Error: Run Time($SECONDS) for $app_name has exceeded Timeout($timeout)\nIf this is a slow starting application, set a higher timeout with -t\nIf this applicaion is always DEPLOYING, you can disable all probes under the Healthcheck Probes Liveness section in the edit configuration\nReverting update.."
            midclt call chart.release.rollback "$app_name" "{\"item_version\": \"$rollback_version\"}" &> /dev/null
            [[ "$startstatus"  ==  "STOPPED" ]] && failed="true" && after_update_actions && unset failed #run back after_update_actions function if the app was stopped prior to update
            break
        elif [[ "$SECONDS" -ge "$timeout" && "$status"  ==  "DEPLOYING" && "$failed" == "true" ]]; then
            echo -e "Error: Run Time($SECONDS) for $app_name has exceeded Timeout($timeout)\nThe application failed to be ACTIVE even after a rollback,\nManual intervention is required\nAbandoning"
            break
        elif [[ "$status"  ==  "STOPPED" ]]; then
            [[ "$count" -le 1 && "$verbose" == "true"  ]] && echo "Verifying Stopped.." && sleep 15 && continue #if reports stopped on FIRST time through loop, double check
            [[ "$count" -le 1  && -z "$verbose" ]] && sleep 15 && continue #if reports stopped on FIRST time through loop, double check
            echo "Stopped" && break #if reports stopped any time after the first loop, assume its extermal services.
        elif [[ "$status"  ==  "ACTIVE" ]]; then
            [[ "$count" -le 1 && "$verbose" == "true"  ]] && echo "Verifying Active.." && sleep 15 && continue #if reports active on FIRST time through loop, double check
            [[ "$count" -le 1  && -z "$verbose" ]] && sleep 15 && continue #if reports active on FIRST time through loop, double check
            echo "Active" && break #if reports active any time after the first loop, assume actually active.
        else
            [[ "$verbose" == "true" ]] && echo "Waiting $((timeout-SECONDS)) more seconds for $app_name to be ACTIVE"
            sleep 15
            continue
        fi
    done
else
    if [[  "$startstatus"  ==  "STOPPED"  ]]; then
        while [[ "0"  !=  "1" ]] #using a constant while loop, then breaking out of the loop with break commands below.
        do
            (( count++ ))
            status=$(cli -m csv -c 'app chart_release query name,update_available,human_version,human_latest_version,status' | grep "^$app_name," | awk -F ',' '{print $2}')
            if [[ "$status"  ==  "STOPPED" ]]; then
                [[ "$count" -le 1 && "$verbose" == "true"  ]] && echo "Verifying Stopped.." && sleep 15 && continue #if reports stopped on FIRST time through loop, double check
                [[ "$count" -le 1  && -z "$verbose" ]] && sleep 15 && continue #if reports stopped on FIRST time through loop, double check
                echo "Stopped" && break #assume actually stopped anytime AFTER the first loop
                break
            elif [[ "$status"  ==  "ACTIVE" ]]; then
                [[ "$count" -le 1 && "$verbose" == "true"  ]] && echo "Verifying Active.." && sleep 15 && continue #if reports active on FIRST time through loop, double check
                [[ "$count" -le 1  && -z "$verbose" ]] && sleep 15 && continue #if reports active on FIRST time through loop, double check
                [[ "$verbose" == "true" ]] && echo "Returing to STOPPED state.."
                midclt call chart.release.scale "$app_name" '{"replica_count": 0}' &> /dev/null && echo "Stopped"|| echo "FAILED"
                break
            elif [[ "$SECONDS" -ge "$timeout" ]]; then
                echo "Error: Run Time($SECONDS) has exceeded Timeout($timeout)"
                break
            else
                [[ "$verbose" == "true" ]] && echo "Waiting $((timeout-SECONDS)) more seconds for $app_name to be ACTIVE"
                sleep 10
                continue
            fi
        done
    fi
fi
}
export -f after_update_actions


prune(){
echo -e "\nPruning Docker Images" && docker image prune -af | grep "^Total" || echo "Failed to Prune Docker Images"
}
export -f prune


title(){
echo ' _   _                        _____           _       _   '
echo '| | | |                      /  ___|         (_)     | | '
echo '| |_| | ___  __ ___   ___   _\ `--.  ___ _ __ _ _ __ | |_'
echo "|  _  |/ _ \/ _\` \ \ / / | | |\`--. \/ __| '__| | '_ \| __|"
echo '| | | |  __/ (_| |\ V /| |_| /\__/ / (__| |  | | |_) | |_ '
echo '\_| |_/\___|\__,_| \_/  \__, \____/ \___|_|  |_| .__/ \__|'
echo '                         __/ |                 | |        '
echo '                        |___/                  |_|        '
echo
}
export -f title


# Parse script options
while getopts ":si:rb:t:uUpSRv-:" opt
do
    case $opt in
      -)
          case "${OPTARG}" in
            help)
                  help="true"
                  ;;
              dns)
                  dns="true"
                  ;;
          restore)
                  restore="true"
                  ;;
            mount)
                  mount="true"
                  ;;
    delete-backup)
                  deleteBackup="true"
                  ;;
                *)
                  echo -e "Invalid Option \"--$OPTARG\"\n" && help
                  exit
                  ;;
          esac
          ;;
      \?)
        echo -e "Invalid Option \"-$OPTARG\"\n" && help
        exit
        ;;
      :)
        echo -e "Option: \"-$OPTARG\" requires an argument\n" && help
        exit
        ;;
      b)
        re='^[0-9]+$'
        number_of_backups=$OPTARG
        ! [[ $OPTARG =~ $re  ]] && echo -e "Error: -b needs to be assigned an interger\n\"""$number_of_backups""\" is not an interger" >&2 && exit
        [[ "$number_of_backups" -le 0 ]] && echo "Error: Number of backups is required to be at least 1" && exit
        ;;
      r)
        rollback="true"
        ;;
      i)
        ignore+=("$OPTARG")
        ;;
      t)
        re='^[0-9]+$'
        timeout=$OPTARG
        ! [[ $timeout =~ $re ]] && echo -e "Error: -t needs to be assigned an interger\n\"""$timeout""\" is not an interger" >&2 && exit
        ;;
      s)
        sync="true"
        ;;
      U)
        update_all_apps="true"
        ;;
      u)
        update_apps="true"
        ;;
      S)
        stop_before_update="true"
        ;;
      p)
        prune="true"
        ;;
      R)
        rollback="true"
        echo "WARNING: -R is being transisitioned to -r, this is due to a refactor in the script. Please Make the change ASAP!"
        ;;
      v)
        verbose="true"
        ;;
      *)
        echo -e "Invalid Option \"--$OPTARG\"\n" && help
        exit
        ;;
    esac
done


#exit if incompatable functions are called
[[ "$update_all_apps" == "true" && "$update_apps" == "true" ]] && echo -e "-U and -u cannot BOTH be called" && exit

#Continue to call functions in specific order
[[ "$help" == "true" ]] && help
[[ "$deleteBackup" == "true" ]] && deleteBackup && exit
[[ "$dns" == "true" ]] && dns && exit
[[ "$restore" == "true" ]] && restore && exit
[[ "$mount" == "true" ]] && mount && exit
[[ "$number_of_backups" -ge 1 ]] && backup
[[ "$sync" == "true" ]] && sync
[[ "$update_all_apps" == "true" || "$update_apps" == "true" ]] && update_apps
[[ "$prune" == "true" ]] && prune
