#!/bin/bash
#If no argument is passed, kill the script.
[[ -z "$*" ]] && echo "This script requires an arguent, use -h for help" && exit

while getopts ":hsi:mrb:t:uUpSRv" opt
do
  case $opt in
    h)
      echo "-m | Initiates mounting feature, choose between unmounting and mounting PVC data"
      echo "-r | Opens a menu to restore a heavy_script backup that was taken on you ix-applications pool"
      echo "-b | Back-up your ix-applications dataset, specify a number after -b"
      echo "-i | Add application to ignore list, one by one, see example below."
      echo "-R | Roll-back applications if they fail to update"
      echo "-S | Shutdown applications prior to updating"
      echo "-v | verbose output"
      echo "-t | Set a custom timeout in seconds when checking if either an App or Mountpoint correctly Started, Stopped or (un)Mounted. Defaults to 500 seconds"
      echo "-s | sync catalog"
      echo "-S | Stops App before update with -u or -U and restarts afterwards"
      echo "-U | Update all applications, ignores versions"
      echo "-u | Update all applications, does not update Major releases"
      echo "-p | Prune unused/old docker images"
      echo "-s | Stop App before attempting update"
      echo "EX | bash heavy_script.sh -b 14 -i portainer -i arch -i sonarr -i radarr -t 600 -vRsUp"
      echo "EX | bash /mnt/tank/scripts/heavy_script.sh -t 8812 -m"
      exit
      ;;
    \?)
      echo "Invalid Option -$OPTARG, type -h for help"
      exit
      ;;
    :)
      echo "Option: -$OPTARG requires an argument" >&2
      exit
      ;;
    b)
      re='^[0-9]+$'
      ! [[ $OPTARG =~ $re  ]] && echo -e "Error: -b needs to be assigned an interger\n$number_of_backups is not an interger" >&2 && exit
      number_of_backups=$OPTARG
      echo -e "\nNumber of backups was set to $number_of_backups"
      ;;
    r)
      restore="true"
      ;;
    i)
      ignore+=("$OPTARG")
      ;;
    t)
      re='^[0-9]+$'
      timeout=$OPTARG
      ! [[ $timeout =~ $re ]] && echo -e "Error: -t needs to be assigned an interger\n$timeout is not an interger" >&2 && exit
      ;;
    m)
      mount="true"
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
      ;;
    v)
      verbose="true"
      ;;
  esac
done

backup(){
date=$(date '+%Y_%m_%d_%H_%M_%S')
[[ "$verbose" == "true" ]] && cli -c 'app kubernetes backup_chart_releases backup_name=''"'HeavyScript_"$date"'"'
[[ -z "$verbose" ]] && echo -e "\nNew Backup Name:" && cli -c 'app kubernetes backup_chart_releases backup_name=''"'HeavyScript_"$date"'"' | tail -n 1
mapfile -t list_backups < <(cli -c 'app kubernetes list_backups' | grep "HeavyScript_" | sort -t '_' -Vr -k2,7 | awk -F '|'  '{print $2}'| tr -d " \t\r")
if [[  ${#list_backups[@]}  -gt  "number_of_backups" ]]; then
  echo -e "\nDeleting the oldest backup(s) for exceeding limit:"
  overflow=$(expr ${#list_backups[@]} - $number_of_backups)
  mapfile -t list_overflow < <(cli -c 'app kubernetes list_backups' | grep "HeavyScript_"  | sort -t '_' -Vr -k2,7 | awk -F '|'  '{print $2}'| tr -d " \t\r" | tail -n "$overflow")
  for i in "${list_overflow[@]}"
  do
    cli -c 'app kubernetes delete_backup backup_name=''"'"$i"'"' &> /dev/null || echo "Failed to delete $i"
    echo "$i"
  done
fi
}
export -f backup

restore(){
list_backups=$(cli -c 'app kubernetes list_backups' | grep "HeavyScript_" | sort -rV | tr -d " \t\r"  | awk -F '|'  '{print NR-1, $2}' | column -t) && echo "$list_backups" && read -p "Please type a number: " selection && restore_point=$(echo "$list_backups" | grep ^"$selection" | awk '{print $2}') && echo -e "\nThis is NOT guranteed to work\nThis is ONLY supposed to be used as a LAST RESORT\nConsider rolling back your applications instead if possible.\n\nYou have chosen to restore $restore_point\nWould you like to continue?"  && echo -e "1  Yes\n2  No" && read -p "Please type a number: " yesno || { echo "FAILED"; exit; }
if [[ $yesno == "1" ]]; then
  echo -e "\nStarting Backup, this will take a LONG time." && cli -c 'app kubernetes restore_backup backup_name=''"'"$restore_point"'"' || echo "Restore FAILED"
elif [[ $yesno == "2" ]]; then
  echo "You've chosen NO, killing script. Good luck."
else
  echo "Invalid Selection"
fi
}
export -f restore

mount(){
echo -e "1  Mount\n2  Unmount All" && read -p "Please type a number: " selection

if [[ $selection == "1" ]]; then
  list=$(k3s kubectl get pvc -A | sort -u | awk '{print NR-1, "\t" $1 "\t" $2 "\t" $4}' | column -t | sed "s/^0/ /")
  echo "$list" && read -p "Please type a number : " selection
  app=$(echo -e "$list" | grep ^"$selection" | awk '{print $2}' | cut -c 4-)
  pvc=$(echo -e "$list" | grep ^"$selection" || echo -e "\nInvalid selection")
  status=$(cli -m csv -c 'app chart_release query name,status' | grep -E "(,|^)$app(,|$)" | awk -F ',' '{print $2}'| tr -d " \t\n\r")
  if [[ "$status" != "STOPPED" ]]; then
    [[ -z $timeout ]] && echo -e "\nDefault Timeout: 500" && timeout=500 || echo -e "\nCustom Timeout: $timeout"
    SECONDS=0 && echo -e "\nScaling down $app" && midclt call chart.release.scale "$app" '{"replica_count": 0}' &> /dev/null
  else
    echo -e "\n$app is already stopped"
  fi
  while [[ "$SECONDS" -le "$timeout" && "$status" != "STOPPED" ]]
    do
      status=$(cli -m csv -c 'app chart_release query name,status' | grep -E "(,|^)$app(,|$)" | awk -F ',' '{print $2}'| tr -d " \t\n\r")
      echo -e "Waiting $((timeout-SECONDS)) more seconds for $app to be STOPPED" && sleep 10
    done
  data_name=$(echo "$pvc" | awk '{print $3}')
  mount=$(echo "$pvc" | awk '{print $4}')
  volume_name=$(echo "$pvc" | awk '{print $4}')
  full_path=$(zfs list | grep $volume_name | awk '{print $1}')
  echo -e "\nMounting\n"$full_path"\nTo\n/mnt/temporary/$data_name" && zfs set mountpoint=/temporary/"$data_name" "$full_path" && echo -e "Mounted\n\nUnmount with the following command\nzfs set mountpoint=legacy "$full_path" && rmdir /mnt/temporary/"$data_name"\nOr use the Unmount All option\n"
  exit
elif [[ $selection == "2" ]]; then
  mapfile -t unmount_array < <(basename -a /mnt/temporary/* | sed "s/*//")
  [[ -z $unmount_array ]] && echo "Theres nothing to unmount" && exit
  for i in "${unmount_array[@]}"
    do
      main=$(k3s kubectl get pvc -A | grep "$i" | awk '{print $1, $2, $4}')
      app=$(echo "$main" | awk '{print $1}' | cut -c 4-)
      pvc=$(echo "$main" | awk '{print $3}')
      path=$(find /*/*/ix-applications/releases/"$app"/volumes/ -maxdepth 0 | cut -c 6-)
      zfs set mountpoint=legacy "$path""$pvc" && echo "$i unmounted" && rmdir /mnt/temporary/"$i" || echo "failed to unmount $i"
    done
else
  echo "Invalid selection, type -h for help"
  break
fi
}
export -f mount

sync(){
echo -e "\nSyncing all catalogs, please wait.." && cli -c 'app catalog sync_all' &> /dev/null && echo -e "Catalog sync complete"
}
export -f sync

prune(){
echo -e "\nPruning Docker Images" && docker image prune -af | grep Total || echo "Failed to Prune Docker Images"
}
export -f prune

update_apps(){
    mapfile -t array < <(cli -m csv -c 'app chart_release query name,update_available,human_version,human_latest_version,container_images_update_available,status' | grep ",true" | sort)
    [[ -z $array ]] && echo -e "\nThere are no updates available" || echo -e "\n${#array[@]} update(s) available"
    [[ -z $timeout ]] && echo -e "\nDefault Timeout: 500" && timeout=500 || echo -e "\nCustom Timeout: $timeout"
        for i in "${array[@]}"
            do
                app_name=$(echo "$i" | awk -F ',' '{print $1}') #print out first catagory, name.
                old_app_ver=$(echo "$i" | awk -F ',' '{print $4}' | awk -F '_' '{print $1}' | awk -F '.' '{print $1}') #previous/current Application MAJOR Version
                new_app_ver=$(echo "$i" | awk -F ',' '{print $5}' | awk -F '_' '{print $1}' | awk -F '.' '{print $1}') #new Application MAJOR Version
                old_chart_ver=$(echo "$i" | awk -F ',' '{print $4}' | awk -F '_' '{print $2}' | awk -F '.' '{print $1}') # Old Chart MAJOR version
                new_chart_ver=$(echo "$i" | awk -F ',' '{print $5}' | awk -F '_' '{print $2}' | awk -F '.' '{print $1}') # New Chart MAJOR version
                status=$(echo "$i" | awk -F ',' '{print $2}') #status of the app: STOPPED / DEPLOYING / ACTIVE
                diff_app=$(diff <(echo "$old_app_ver") <(echo "$new_app_ver")) #caluclating difference in major app versions
                diff_chart=$(diff <(echo "$old_chart_ver") <(echo "$new_chart_ver")) #caluclating difference in Chart versions
                old_full_ver=$(echo "$i" | awk -F ',' '{print $4}') #Upgraded From
                new_full_ver=$(echo "$i" | awk -F ',' '{print $5}') #Upraded To
                rollback_version=$(echo "$i" | awk -F ',' '{print $4}' | awk -F '_' '{print $2}')
                printf '%s\0' "${ignore[@]}" | grep -iFxqz "${app_name}" && echo -e "\n$app_name\nIgnored, skipping" && continue #If application is on ignore list, skip
                if [[ "$diff_app" == "$diff_chart" || "$update_all_apps" == "true" ]]; then #continue to update
                  startstatus=$status
                  if [[ $stop_before_update == "true" ]]; then # Check to see if user is using -S or not
                      if [[ "$status" ==  "STOPPED" ]]; then # if status is already stopped, skip while loop
                        echo -e "\n$app_name"
                        [[ "$verbose" == "true" ]] && echo "Updating..."
                        cli -c 'app chart_release upgrade release_name=''"'"$app_name"'"' &> /dev/null && echo -e "Updated\n$old_full_ver\n$new_full_ver" && after_update_actions || echo "FAILED"
                        continue
                      else # if status was not STOPPED, stop the app prior to updating
                        echo -e "\n"$app_name""
                        [[ "$verbose" == "true" ]] && echo "Stopping prior to update..."
                        midclt call chart.release.scale "$app_name" '{"replica_count": 0}' &> /dev/null && SECONDS=0 || echo -e "FAILED"
                        while [[ "$status" !=  "STOPPED" ]]
                        do
                            status=$(cli -m csv -c 'app chart_release query name,update_available,human_version,human_latest_version,status' | grep ""$app_name"," | awk -F ',' '{print $2}')
                            if [[ "$status"  ==  "STOPPED" ]]; then
                                echo "Stopped"
                                [[ "$verbose" == "true" ]] && echo "Updating..."
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
                      [[ "$verbose" == "true" ]] && echo "Updating..."
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
        status=$(cli -m csv -c 'app chart_release query name,update_available,human_version,human_latest_version,status' | grep ""$app_name"," | awk -F ',' '{print $2}')
        if [[ "$status"  ==  "ACTIVE" && "$startstatus"  ==  "STOPPED" ]]; then
            [[ "$verbose" == "true" ]] && echo "Returing to STOPPED state.."
            midclt call chart.release.scale "$app_name" '{"replica_count": 0}' &> /dev/null && echo "Stopped"|| echo "FAILED"
            break
        elif [[ "$SECONDS" -ge "$timeout" && "$status"  ==  "DEPLOYING" && "$failed" != "true" ]]; then
            echo -e "Error: Run Time($SECONDS) for $app_name has exceeded Timeout($timeout)\nIf this is a slow starting application, set a higher timeout with -t\nIf this applicaion is always DEPLOYING, you can disable all probes under the Healthcheck Probes Liveness section in the edit configuration\nReverting update..."
            midclt call chart.release.rollback "$app_name" "{\"item_version\": \"$rollback_version\"}" &> /dev/null
            [[ "$startstatus"  ==  "STOPPED" ]] && failed="true" && after_update_actions && unset failed #run back after_update_actions function if the app was stopped prior to update
            break
        elif [[ "$SECONDS" -ge "$timeout" && "$status"  ==  "DEPLOYING" && "$failed" == "true" ]]; then
            echo -e "Error: Run Time($SECONDS) for $app_name has exceeded Timeout($timeout)\nThe application failed to be ACTIVE even after a rollback,\nManual intervention is required\nAbandoning"
            break
        elif [[ "$status"  ==  "STOPPED" ]]; then
            [[ "$count" -le 1 ]] && echo "Verifying Stopped.." && sleep 15 && continue #if reports stopped on FIRST time through loop, double check
            [[ "$count" -ge 2 ]] && echo "Error: Application appears to be stuck in stopped state" && break #if reports stopped any time after the first loop, assume its broken.
        elif [[ "$status"  ==  "ACTIVE" ]]; then
            [[ "$count" -le 1 ]] && echo "Verifying Active.." && sleep 15 && continue #if reports active on FIRST time through loop, double check
            [[ "$count" -ge 2 ]] && echo "Active" && break #if reports active any time after the first loop, assume actually active.
        else
            [[ "$verbose" == "true" ]] && echo "Waiting $((timeout-SECONDS)) more seconds for $app_name to be ACTIVE"
            sleep 15
            continue
        fi
    done
else
    if [[  "$startstatus"  ==  "STOPPED"  ]]; then
        status=$(cli -m csv -c 'app chart_release query name,update_available,human_version,human_latest_version,status' | grep ""$app_name"," | awk -F ',' '{print $2}')
        while [[ "$status" !=  "STOPPED" ]]
        do
            (( count++ ))
            [[ "$count" -ge 2 ]] && status=$(cli -m csv -c 'app chart_release query name,update_available,human_version,human_latest_version,status' | grep ""$app_name"," | awk -F ',' '{print $2}') #Skip first status check, due to the one directly above it.
            if [[ "$status"  ==  "STOPPED" ]]; then
                echo "Stopped"
                break
            elif [[ "$status"  ==  "ACTIVE" ]]; then
                [[ "$verbose" == "true" ]] && echo "Returing to STOPPED state.."
                midclt call chart.release.scale "$app_name" '{"replica_count": 0}' &> /dev/null && echo "Stopped"|| echo "FAILED"
                break
            elif [[ "$SECONDS" -ge "$timeout" ]]; then
                echo "Error: Run Time($SECONDS) has exceeded Timeout($timeout)"
                break
            elif [[ "$status" !=  "STOPPED" ]]; then
                [[ "$verbose" == "true" ]] && echo "Waiting $((timeout-SECONDS)) more seconds for $app_name to be ACTIVE"
                sleep 10
                continue
            fi
        done
    fi
fi
}
export -f prune

[[ $restore == "true" ]] && restore && exit
[[ $number_of_backups -gt 0 ]] && backup
[[ $mount == "true" ]] && mount && exit
[[ $sync == "true" ]] && sync
[[ $update_all_apps == "true" || $update_apps == "true" ]] && update_apps
[[ $prune == "true" ]] && prune
