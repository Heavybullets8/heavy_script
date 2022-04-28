# heavy_script
Script that can: Update Truenas SCALE applications, Mount and unmount PVC storage, Prune Docker images.


## These arguments NEED to be ran in a specific order, you can go from TOP to BOTTOM, see example below
- -m | Initiates mounting feature, choose between unmounting and mounting PVC data"
- -r | Opens a menu to restore a HeavyScript backup that was taken on you ix-applications pool"
- -b | Back-up your ix-applications dataset, specify a number after -b"
- -i | Add application to ignore list, one by one, see example below."
- -t | Set a custom timeout in seconds for -u or -U: This is the ammount of time the script will wait for an application to go from DEPLOYING to ACTIVE"
- -t | Set a custom timeout in seconds for -m: Amount of time script will wait for applications to stop, before timing out"
- -s | sync catalog"
- -U | Update all applications, ignores versions"
- -u | Update all applications, does not update Major releases"
- -p | Prune unused/old docker images"



### Examples
- bash heavy_script.sh -b 14 -i portainer -i arch -i sonarr -i radarr -t 600 -sUp"
- bash /mnt/tank/scripts/heavy_script.sh -t 8812 -m"
