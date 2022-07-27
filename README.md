# heavy_script

## Table of contents:
* [Arguments](#arguments)
* [Examples](#examples)
* [How to Install](#how-to-install)
* [How to Update](#how-to-update)
* [Creating a Cron Job](#creating-a-cron-job)
* [Additional Information](#additional-information)

<br>

## Arguments

| Flag            	| Example                	| Parameter 	| Description                                                                                                                                                                                                                           	|
|-----------------	|------------------------	|-----------	|---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------	|
| --self-update   	| --self-update          	| None      	| Updates HeavyScript prior to running it<br>_You no longer need to git pull_                                                                                                                                                           	|
| --delete-backup 	| --delete-backup        	| None      	| Opens a menu to delete backups<br>_Useful if you need to delete old system backups or backups from other scripts_                                                                                                                     	|
| --restore       	| --restore              	| None      	| Restore HeavyScript specific `ix-applications dataset` snapshot                                                                                                                                                                       	|
| --mount         	| --mount                	| None      	| Initiates mounting feature<br>Choose between unmounting and mounting PVC data                                                                                                                                                         	|
| --dns           	| --dns                  	| None      	| list all of your applications DNS names and their web ports                                                                                                                                                                           	|
| -U              	| -U                     	| None      	| Update applications, ignoring major version changes                                                                                                                                                                                   	|
| -u              	| -u                     	| None      	| Update applications, do NOT update if there was a major version change                                                                                                                                                                	|
| -b              	| -b 14                  	| Integer   	| Backup `ix-appliactions` dataset<br>_Creates backups up to the number you've chosen_                                                                                                                                                  	|
| -i              	| -i nextcloud -i sonarr 	| String    	| Applications listed will be ignored during updating<br>_List one application after another as shown in the example_                                                                                                                   	|
| (-R\|-r)        	| -r                     	| None      	| Monitors applications after they update<br>If the app does not become "ACTIVE" after either:<br>The custom Timeout, or Default Timeout,<br>rollback the application.<br>__Warning: deprecating `-R` please begin using `-r` instead__ 	|
| -v              	| -v                     	| None      	| Verbose Output<br>_Look at the bottom of this page for an example_                                                                                                                                                                    	|
| -S              	| -S                     	| None      	| Shutdown the application prior to updating it                                                                                                                                                                                         	|
| -t              	| -t 150                 	| Integer   	| Set a custom timeout to be used with either:<br>`-m` <br>_Time the script will wait for application to be "STOPPED"_<br>or<br>`-(u\|U)` <br>_Time the script will wait for application to be either "STOPPED" or "ACTIVE"_            	|
| -s              	| -s                     	| None      	| Sync Catalogs prior to updating                                                                                                                                                                                                       	|
| -p              	| -p                     	| None      	| Prune old/unused docker images                                                                                                                                                                                                        	|


<br>
<br>

### Examples
#### Typical Cron Job  
```
bash heavy_script.sh --self-update -b 14 -i portainer -i arch -i sonarr -i radarr -t 600 -rsup
```

> `-b` is set to 14. Up to 14 snapshots of your ix-applications dataset will be saved

> `-i` is set to ignore portainer, arch, sonarr, and radarr. These applications will be ignored when it comes to updates.

> `-t` I set it to 600 seconds, this means the script will wait 600 seconds for the application to become ACTIVE before timing out and continuing to a different application. 

> `-r` Will rollback applications if they fail to deploy after updating.

> `-s` will just sync the repositories, ensuring you are downloading the latest updates.

> `-u` update applications as long as the major version has absolutely no change, if it does have a change it will ask the user to update manually.

> `-p` Prune docker images.

> `--self-update` Will update the script prior to running anything else.

#### Mounting PVC Data

```
bash /mnt/tank/scripts/heavy_script.sh -t 300 --mount
```

#### Restoring ix-applications dataset

```
bash /mnt/tank/scripts/heavy_script/heavy_script.sh --restore
```

#### Deleting Backups

```
bash /mnt/tank/scripts/heavy_script/heavy_script.sh --delete-backup
```

#### List All DNS Names

```
bash /mnt/tank/scripts/heavy_script/heavy_script.sh --dns
```

#### My personal Cron Job
```
bash /mnt/speed/scripts/heavy_script/heavy_script.sh --self-update -b 14 -rsup
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

> Note: `chmod +x` is NOT required. Doing this will break the `git pull` (or self update) function. Just run the script with `bash heavy_script.sh`

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

### Update with the scripts built-in option

```
bash heavyscript.sh --self-update -b 14 -supr
```
> The important argument here is the `--self-update`, you can still use all of your same arguments with this option.


<br >
<br >

## Creating a Cron Job

1. TrueNAS SCALE GUI
2. System Settings
3. Advanced
4. Cron Jobs
   1. Click Add

| Name                   	| Value                                                                                                             	| Reason                                                                                                                                                                                         	|
|------------------------	|-------------------------------------------------------------------------------------------------------------------	|------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------	|
| `Description`          	| HeavyScript git pull and Update apps                                                                              	| This is up to you, put whatever you think is a good description in here                                                                                                                        	|
| `Command`              	| `bash /PATH/TO/HEAVY_SCRIPT_DIRECTORY/heavy_script.sh --self-update -b 14 -rsup` 	| This is the command you will be running on your schedule  I personally use:  `bash /mnt/speed/scripts/heavy_script/heavy_script.sh --self-update -b 14 -rsup` 	|
| `Run As User`          	| `root`                                                                                                            	| Running the script as `root` is REQUIRED. You cannot access all of the kubernetes functions without this user.                                                                                 	|
| `Schedule`             	| Up to you, I run mine everyday at `0400`                                                                          	| Again up to you                                                                                                                                                                                	|
| `Hide Standard Output` 	| `False` or Unticked                                                                                               	| I like to receive an email report of how the script ran, what apps updated etc.                                                                                                                	|
| `Hide Standard Error`  	| `False`  or Unticked                                                                                              	| I want to see any errors that occur                                                                                                                                                            	|
| `Enabled`              	| `True` or Ticked                                                                                                  	| This will Enable the script to run on your schedule                                                                                                                                            	|



<br >
<br >

### Additional Information

#### Verbose vs Non-Verbose 
-  Verbose used `bash heavy_script.sh -b 5 -Srupv`
- Non-Verbose used `bash heavy_script.sh -b 5 -Srup`

| Verbose 	| Non-Verbose 	|
|---------	|-------------	|
|  ![image](https://user-images.githubusercontent.com/20793231/167971188-07f71d02-8da3-4e0c-b9a0-cd26e7f63613.png) |   ![image](https://user-images.githubusercontent.com/20793231/167972033-dc8d4ab4-4fb2-4c8a-b7dc-b9311ae55cf8.png) |
       

