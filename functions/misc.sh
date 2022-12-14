#!/bin/bash


sync(){
echo_sync+=("🅂 🅈 🄽 🄲") 
cli -c 'app catalog sync_all' &> /dev/null && echo_sync+=("Catalog sync complete")

#Dump the echo_array, ensures all output is in a neat order. 
for i in "${echo_sync[@]}"
do
    echo -e "$i"
done
echo
echo
}
export -f sync


prune(){
echo -e "🄿 🅁 🅄 🄽 🄴"  
echo "Pruned Docker Images"
if ! cli -c 'app container config prune prune_options={"remove_unused_images": true, "remove_stopped_containers": true}' | head -n -4; then
    echo "Failed to Prune Docker Images"
fi
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
echo "$hs_version"
echo
}
export -f title


help(){
[[ $help == "true" ]] && clear -x

echo "Access the HeavyScript Menu"
echo "---------------------------"
echo "bash heavy_script.sh"
echo
echo "Utilities"
echo "---------"
echo "--mount         | Initiates mounting feature, choose between unmounting and mounting PVC data"
echo "--restore       | Opens a menu to restore a \"heavy_script\" backup that was taken on your \"ix-applications\" dataset"
echo "--delete-backup | Opens a menu to delete backups on your system"
echo "--dns           | list all of your applications DNS names and their web ports"
echo "--cmd           | Open a shell for one of your applications"
echo
echo "Update Types"
echo "------------"
echo "-U    | Update all applications, ignores versions"
echo "-U 5  | Same as above, but updates 5 applications at one time"
echo "-u    | Update all applications, does not update Major releases"
echo "-u 5  | Same as above, but updates 5 applications at one time"
echo
echo "Update Options"
echo "--------------"
echo "-r    | Roll-back applications if they fail to update"
echo "-i    | Add application to ignore list, one by one, see example below."
echo "-S    | Shutdown applications prior to updating"
echo "-v    | verbose output"
echo "-t 500| The amount of time HS will wait for an application to be ACTIVE. Defaults to 500 seconds"
echo
echo "Additional Options"
echo "------------------"
echo "-b 14 | Back-up your ix-applications dataset, specify a number after -b"
echo "-s    | sync catalog"
echo "-p    | Prune unused/old docker images"
echo "--ignore-img  | Ignore container image updates"
echo "--self-update | Updates HeavyScript prior to running any other commands"
echo
echo "Examples"
echo "--------"
echo "bash heavy_script.sh"
echo "bash heavy_script.sh -b 14 -i portainer -i arch -i sonarr -t 600 -vrsUp --self-update"
echo "bash heavy_script.sh -b 14 -i portainer -i arch -i sonarr -t 600 -vrsp -U 10 --self-update"
echo "bash /mnt/tank/scripts/heavy_script.sh -t 150 --mount"
echo "bash /mnt/tank/scripts/heavy_script.sh --dns"
echo "bash heavy_script.sh --restore"
echo "bash /mnt/tank/scripts/heavy_script.sh --delete-backup"
echo
exit
}
export -f help