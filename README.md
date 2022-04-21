# heavy_script
Script that can: Update Truenas SCALE applications, Mount and unmount PVC storage, Prune Docker images.


These arguments NEED to be ran in a specific order, you can go from TOP to BOTTOM, see example below
| -m | Initiates mounting feature, choose between unmounting and mounting PVC data
| -i | Add application to ignore list, one by one, see example below.
| -t | Default: 300 -- Set a custom timeout: This is the ammount of time the script will wait for an application to go from DEPLOYING to ACTIVE
| -s |sync catalog
| -U | Update all applications, ignores versions
| -u | Update all applications, does not update Major releases
| -p | Prune unused/old docker images
| EX |./update.sh -i portainer -i arch -i sonarr -i radarr -t 600 -sUp
