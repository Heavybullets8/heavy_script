#!/bin/bash


sync(){
cli -c 'app catalog sync_all' &> /dev/null && echo_sync+=("Catalog sync complete")

#Dump the echo_array, ensures all output is in a neat order. 
for i in "${echo_sync[@]}"
do
    echo -e "$i"
done
}
export -f sync

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

help(){
[[ $help == "true" ]] && clear -x
echo "Basic Utilities"
echo "--mount         | Initiates mounting feature, choose between unmounting and mounting PVC data"
echo "--restore       | Opens a menu to restore a \"heavy_script\" backup that was taken on your \"ix-applications\" dataset"
echo "--delete-backup | Opens a menu to delete backups on your system"
echo "--dns           | list all of your applications DNS names and their web ports"
echo
echo "Update Options"
echo "-U | Update all applications, ignores versions"
echo "-u | Update all applications, does not update Major releases"
echo "-b | Back-up your ix-applications dataset, specify a number after -b"
echo "-i | Add application to ignore list, one by one, see example below."
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
echo "bash heavy_script.sh --restore"
echo "bash /mnt/tank/scripts/heavy_script.sh --delete-backup"
echo
exit
}
export -f help