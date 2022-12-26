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
version="$(cli -c 'system version' | awk -F '-' '{print $3}' | awk -F '.' '{print $1 $2}' |  tr -d " \t\r\.")"
if (( "$version" >= 2212 )); then
    if ! cli -c 'app container config prune prune_options={"remove_unused_images": true, "remove_stopped_containers": true}' | head -n -4; then
        echo "Failed to Prune Docker Images"
    fi
else
    if ! docker image prune -af | grep "^Total"; then
        echo "Failed to Prune Docker Images"
    fi
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



patch_2212_backups(){
clear -x
#Check TrueNAS version, skip if not 22.12.0
if ! [ "$(cli -m csv -c 'system version' | awk -F '-' '{print $3}')" == "22.12.0" ]; then
    echo "This patch does not apply to your version of TrueNAS"
    return
fi


#Description
echo "This patch will fix the issue with backups not restoring properly"
echo "Due to Ix-Systems not saving PVC in backups, this patch will fix that"
echo "Otherwise backups will not restore properly"
echo "You only need to run this patch once, it will not run again"
echo


#Download patch
echo "Downloading Backup Patch"
if ! wget -q https://github.com/truecharts/truetool/raw/main/hotpatch/2212/HP1.patch; then
    echo "Failed to download Backup Patch"
    exit
else
    echo "Downloaded Backup Patch"
fi

echo

# Apply patch
echo "Applying Backup Patch"
if patch -N --reject-file=/dev/null -s -p0 -d /usr/lib/python3/dist-packages/middlewared/ < HP1.patch &>/dev/null; then
    echo "Backup Patch applied"
    rm -rf HP1.patch
else
    echo "Backup Patch already applied"
    rm -rf HP1.patch
    exit
fi

echo

#Restart middlewared
while true
do
    echo "We need to restart middlewared to finish the patch"
    echo "This will cause a short downtime for some minor services approximately 10-30 seconds"
    echo "Applications should not be affected"
    read -rt 120 -p "Would you like to proceed? (y/N): " yesno || { echo -e "\nFailed to make a selection in time" ; exit; }
    case $yesno in
        [Yy] | [Yy][Ee][Ss])
            echo "Restarting middlewared"
            service middlewared restart &
            wait $!
            echo "Restarted middlewared"
            echo "You are set, there is no need to run this patch again"
            break
            ;;
        [Nn] | [Nn][Oo])
            echo "Exiting"
            echo "Please restart middlewared manually"
            echo "You can do: service middlewared restart"
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


patch_2212_backups2(){
clear -x
#Check TrueNAS version, skip if not 22.12.0
if ! [ "$(cli -m csv -c 'system version' | awk -F '-' '{print $3}')" == "22.12.0" ]; then
    echo "This patch does not apply to your version of TrueNAS"
    return
fi


#Description
echo "This patch will fix the issue certain applicattions breaking backups"
echo "You only need to run this patch once, it will not run again"
echo


# Apply patch
echo "Applying Backup Patch"
if patch -N --reject-file=/dev/null -s -p0 /usr/lib/python3/dist-packages/middlewared/plugins/kubernetes_linux/backup.py < patches/backups.patch &>/dev/null; then
    echo "Backup Patch applied"
else
    echo "Backup Patch already applied"
    exit
fi

echo

#Restart middlewared
while true
do
    echo "We need to restart middlewared to finish the patch"
    echo "This will cause a short downtime for some minor services approximately 10-30 seconds"
    echo "Applications should not be affected"
    read -rt 120 -p "Would you like to proceed? (y/N): " yesno || { echo -e "\nFailed to make a selection in time" ; exit; }
    case $yesno in
        [Yy] | [Yy][Ee][Ss])
            echo "Restarting middlewared"
            service middlewared restart &
            wait $!
            echo "Restarted middlewared"
            echo "You are set, there is no need to run this patch again"
            break
            ;;
        [Nn] | [Nn][Oo])
            echo "Exiting"
            echo "Please restart middlewared manually"
            echo "You can do: service middlewared restart"
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

