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


## How to Install

### Create a Scripts Dataset

I created a `scripts` dataset on my Truenas SCALE system, this is where all my scripts will remain.

### Open a Terminal 

**Change Directory to your scripts folder**
```
cd /mnt/speed/scripts
```

**Git Clone Heavy_Script**
```
git clone https://github.com/Heavybullets8/heavy_script.git
```

**Change Directory to Heavy_Script folder**
```
cd heavy_script
```

From here, you can just run Heavy_Script with `bash heavy_script.sh -ARGUMENTS`

> Note: `chmod +x` is NOT required. Doing this will break the `git pull` function. Just run the script with `bash heavy_script.sh`

<br>

## How to Update 

### Manually

#### Open a Terminal 

**Change Directory to your heavy_script folder**
```
cd /mnt/speed/scripts/heavy_script
```

**git pull**
```
git pull
```
<br >

### Update with your Cron Job

Here, we will update the script prior to running it, incase there is a bugfix, or any new additions to the script

**Cron Job Command**
```
git -C /mnt/speed/scripts/heavy_script pull && bash /mnt/speed/scripts/heavy_script/heavy_script.sh -b 14 -Rsup
```
> The important command here is the `git -C /PATH/TO/HEAVY_SCRIPT_DIRECTORY pull`

> This command will allow you to preform a `git pull` on a remote directory, which will ensure your script is udated prior to running it

> `&&` Is used to run a command AFTER the previous command completed successfully
>> So once the `git -C /PATH/TO/HEAVY_SCRIPT_DIRECTORY pull` command completes, THEN it will run the `bash /PATH/TO/HEAVY_SCRIPT_DIRECTORY/heavy_script.sh -b 14 -Rsup` command

<br >
<br >

## Creating a Cron Job

1. Truenas SCALE GUI
2. System Settings
3. Advanced
4. Cron Jobs
   1. Click Add

| Name                   	| Value                                                                                                             	| Reason                                                                                                                                                                                         	|
|------------------------	|-------------------------------------------------------------------------------------------------------------------	|------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------	|
| `Description`          	| HeavyScript git pull and Update apps                                                                              	| This is up to you, put whatever you think is a good description in here                                                                                                                        	|
| `Command`              	| `git -C /PATH/TO/HEAVY_SCRIPT_DIRECTORY pull && bash /PATH/TO/HEAVY_SCRIPT_DIRECTORY/heavy_script.sh -b 14 -Rsup` 	| This is the command you will be running on your schedule  I personally use:  `git -C /mnt/speed/scripts/heavy_script pull && bash /mnt/speed/scripts/heavy_script/heavy_script.sh -b 14 -Rsup` 	|
| `Run As User`          	| `root`                                                                                                            	| Running the script as `root` is REQUIRED. You cannot access all of the kubernetes functions without this user.                                                                                 	|
| `Schedule`             	| Up to you, I run mine everyday at `0400`                                                                          	| Again up to you                                                                                                                                                                                	|
| `Hide Standard Output` 	| `False` or Unticked                                                                                               	| I like to receive an email report of how the script ran, what apps updated etc.                                                                                                                	|
| `Hide Standard Error`  	| `False`  or Unticked                                                                                              	| I want to see any errors that occur                                                                                                                                                            	|
| `Enabled`              	| `True` or Ticked                                                                                                  	| This will Enable the script to run on your schedule                                                                                                                                            	|



<br >
<br >

### Additional Informaton

#### Verbose vs Non-Verbose 
-  Verbose used `bash heavy_test.sh -b 5 -SRupv`
- Non-Verbose used `bash heavy_test.sh -b 5 -SRup`

| Verbose 	| Non-Verbose 	|
|---------	|-------------	|
|  ![image](https://user-images.githubusercontent.com/20793231/167971188-07f71d02-8da3-4e0c-b9a0-cd26e7f63613.png) |   ![image](https://user-images.githubusercontent.com/20793231/167972033-dc8d4ab4-4fb2-4c8a-b7dc-b9311ae55cf8.png) |
       


