#!/bin/bash


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

    # Check if patch has already been applied
    if ! patch -R --dry-run -N -s -p0 -d /usr/lib/python3/dist-packages/middlewared/ < HP1.patch &>/dev/null; then
        # If patch has not been applied, apply it
        if patch -N --reject-file=/dev/null -s -p0 -d /usr/lib/python3/dist-packages/middlewared/ < HP1.patch &>/dev/null; then
            echo "Backup Patch applied"
            rm -rf HP1.patch
        else
            # If patch fails to apply, exit
            echo "Error applying Backup Patch"
            exit 1
        fi
    else
        echo "Backup Patch already applied"
        rm -rf HP1.patch
        exit 0
    fi

    echo

    restart_middlewared
}


patch_2212_backups2(){
    clear -x
    #Check TrueNAS version, skip if not 22.12.0
    check_truenas_version


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

    restart_middlewared
}


restart_middlewared(){
    #Restart middlewared
    while true
    do
        echo "We need to restart middlewared to finish the patch"
        echo "This will cause a short downtime for some minor services approximately 10-30 seconds"
        echo "Applications should not be affected"
        read -rt 120 -p "Would you like to proceed? (y/N): " yesno || { echo -e "\nFailed to make a selection in time" ; exit; }
        case $yesno in
            [Yy] | [Yy][Ee][Ss])
                echo "Restarting middlewared..."
                if systemctl restart middlewared ; then
                    echo "Restarted middlewared"
                    echo "You are set, there is no need to run this patch again"
                    break
                else
                    echo "Failed to restart middlewared"
                    echo "Please restart middlewared manually"
                    echo "You can do: systemctl restart middlewared"
                    exit 1
                fi
                ;;
            [Nn] | [Nn][Oo])
                echo "Exiting"
                echo "Please restart middlewared manually"
                echo "You can do: systemctl restart middlewared"
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


check_truenas_version(){
    #Check TrueNAS version, skip if not 22.12.0
    if ! [ "$(cli -m csv -c 'system version' | awk -F '-' '{print $3}')" == "22.12.0" ]; then
        echo "This patch does not apply to your version of TrueNAS"
        exit
    fi
}

