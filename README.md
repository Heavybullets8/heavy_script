# heavy_script
Script that can: Update Truenas SCALE applications, Mount and unmount PVC storage, Prune Docker images.


- -m | Initiates mounting feature, choose between unmounting and mounting PVC data"
- -r | Opens a menu to restore a HeavyScript backup that was taken on you ix-applications pool"
- -b | Back-up your ix-applications dataset, specify a number after -b"
- -i | Add application to ignore list, one by one, see example below."
- -R | Roll-back applications if they fail to update
- -S | Shutdown applications prior to updating
- -v | verbose output
- -t | Set a custom timeout in seconds for -u or -U: This is the ammount of time the script will wait for an application to go from DEPLOYING to ACTIVE"
- -t | Set a custom timeout in seconds for -m: Amount of time script will wait for applications to stop, before timing out"
- -s | sync catalog"
- -U | Update all applications, ignores versions"
- -u | Update all applications, does not update Major releases"
- -p | Prune unused/old docker images"


### Examples
#### bash heavy_script.sh -b 14 -i portainer -i arch -i sonarr -i radarr -t 600 -sup
- This is your typical cron job implementation. 
- -b is set to 14. Up to 14 snapshots of your ix-applications dataset will be saved
- -i is set to ignore portainer, arch, sonarr, and radarr. These applications will be ignored when it comes to updates.
- -t I set it to 600 seconds, this means the script will wait 600 seconds for the application to become ACTIVE before timing out and continuing to a different application. 
- -s will just sync the repositories, ensuring you are downloading the latest updates
- -u update applications as long as the major version has absolutely no change, if it does have a change it will ask the user to update manually.
- -p Prune docker images.

- bash /mnt/tank/scripts/heavy_script.sh -t 8812 -m
- bash /mnt/tank/scripts/heavy_script/heavy_script.sh -r


### My personal Cron Job
- ```git -C /mnt/speed/scripts/heavy_script pull && bash /mnt/speed/scripts/heavy_script/heavy_script.sh -b 14 -sup```
