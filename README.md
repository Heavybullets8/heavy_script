# heavy_script
Update | Backup | Restore | Mount PVC | Rollback Applications | Sync Catalog | Prune Docker Images


| Flag 	| Example                	| Parameter 	| Description                                                                                                                                                                                                         	|
|------	|------------------------	|-----------	|---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------	|
| -r   	| -r                     	| None      	| Restore HeavyScript specific 'ix-applications dataset' snapshot                                                                                                                                                     	|
| -m   	| -m                     	| None      	| Initiates mounting feature<br>Choose between unmounting and mounting PVC data                                                                                                                                       	|
| -b   	| -b 14                  	| int       	| Backup 'ix-appliactions' dataset<br>Creates backups up to the number you've chosen                                                                                                                                  	|
| -i   	| -i nextcloud -i sonarr 	| String    	| Applications listed will be ignored during updating                                                                                                                                                                 	|
| -R   	| -R                     	| None      	| Monitors applications after they update<br>If the app does not become "ACTIVE" after either:<br>The custom Timeout, or Default Timeout,<br>rollback the application.                                                	|
| -v   	| -v                     	| None      	| Verbose output                                                                                                                                                                                                      	|
| -S   	| -S                     	| None      	| Shutdown applications prior to updating                                                                                                                                                                             	|
| -t   	| -t 150                 	| int       	| Set a custom timeout to be used with either:<br>-m <br>- Time the script will wait for application to be "STOPPED"<br>or<br>-u/U <br>- Time the script will wait for application to be either "STOPPED" or "ACTIVE" 	|
| -s   	| -s                     	| None      	| Sync Catalog before updating                                                                                                                                                                                        	|
| -U   	| -U                     	| None      	| Update applications, ignoring major version changes                                                                                                                                                                 	|
| -u   	| -u                     	| None      	| Update applications, do NOT update if there was a major version change                                                                                                                                              	|
| -p   	| -p                     	| None      	| Prune old/unused docker images                                                                                                                                                                                      	|
<br>
<br>

### Examples
#### Typical Cron Job  
```
bash heavy_script.sh -b 14 -i portainer -i arch -i sonarr -i radarr -t 600 -Rsup
```

- -b is set to 14. Up to 14 snapshots of your ix-applications dataset will be saved
- -i is set to ignore portainer, arch, sonarr, and radarr. These applications will be ignored when it comes to updates.
- -t I set it to 600 seconds, this means the script will wait 600 seconds for the application to become ACTIVE before timing out and continuing to a different application. 
- -R Will rollback applications if they fail to deploy after updating.
- -s will just sync the repositories, ensuring you are downloading the latest updates.
- -u update applications as long as the major version has absolutely no change, if it does have a change it will ask the user to update manually.
- -p Prune docker images.

#### Mounting PVC Data

```
bash /mnt/tank/scripts/heavy_script.sh -t 300 -m
```

#### Restoring ix-applications dataset

```
bash /mnt/tank/scripts/heavy_script/heavy_script.sh -r
```

#### My personal Cron Job
```
git -C /mnt/speed/scripts/heavy_script pull && bash /mnt/speed/scripts/heavy_script/heavy_script.sh -b 14 -Rsup
```

<br>
<br>

### Additional Informaton

#### Verbose vs Non-Verbose 
-  Verbose used `bash heavy_test.sh -b 5 -SRupv`
- Non-Verbose used `bash heavy_test.sh -b 5 -SRup`

| Verbose 	| Non-Verbose 	|
|---------	|-------------	|
|  ![image](https://user-images.githubusercontent.com/20793231/167971188-07f71d02-8da3-4e0c-b9a0-cd26e7f63613.png) |   ![image](https://user-images.githubusercontent.com/20793231/167972033-dc8d4ab4-4fb2-4c8a-b7dc-b9311ae55cf8.png) |
       


