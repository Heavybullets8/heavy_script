# HeavyScript

## Website 

[HeavySetup - Further Explanation](https://heavysetup.info/scripts/heavyscript/about/)

## Table of contents:
* [Update Arguments](#update-arguments)
* [Other Utilities](#other-utilities)
* [How to Install](#how-to-install)
* [How to Update](#how-to-update)
* [Creating a Cron Job](#creating-a-cron-job)
* [Additional Information](#additional-information)

<br>

## The Menu

![image](https://user-images.githubusercontent.com/20793231/209697976-b7a6ec9c-dee7-4707-82d9-58eb7a2d8248.png)
> Access this with `heavyscript`

<br >
<br >

## Update Arguments
| Flag          | Example                | Parameter        | Description                                                                                                                                                                |
|---------------|------------------------|------------------|----------------------------------------------------------------------------------------------------------------------------------------------------------------------------|
| -U            | -U <br>-U 5            | Optional Integer | Update applications, ignoring major version changes<br>_Optionally, you can supply a number after the argument to update multiple applications at once_                    |
| -u            | -u<br>-u 5             | Optional Integer | Update applications, do NOT update if there was a major version change<br>_Optionally, you can supply a number after the argument to update multiple applications at once_ |
| -b            | -b 14                  | Integer          | Snapshot ix-applications dataset<br>_Creates backups UP TO the number you've chosen_                                                                                       |
| -i            | -i nextcloud -i sonarr | String           | Applications listed will be ignored during updating<br>_List one application after another as shown in the example_                                                        |
| -r            | -r                     |                  | Monitors applications after they update<br>If the app does not become "ACTIVE" after the timeout, rollback the application.                                                |
| -v            | -v                     |                  | Verbose Output<br>_Look at the bottom of this page for an example_                                                                                                         |
| -S            | -S                     |                  | Shutdown the application prior to updating it                                                                                                                              |
| -t            | -t 400                 | Integer          | Time in seconds that HeavyScript will wait for an application to no longer be deploying before declaring failure<br>Default: 500                                           |
| -s            | -s                     |                  | Sync Catalogs prior to updating                                                                                                                                            |
| -p            | -p                     |                  | Prune unused docker images                                                                                                                                                 |
| --ignore-img  | --ignore-img           |                  | Ignore container image updates                                                                                                                                             |
| --self-update | --self-update          |                  | Updates HeavyScript prior to running any other commands                                                                                                                    |


### Example
#### Cron Job  
```
heavyscript --self-update -b 10 -i nextcloud -i sonarr -t 600 --ignore-img -rsp -u 5
```

> `-b` is set to 10. Up to 10 snapshots of your ix-applications dataset will be saved

> `-i` is set to ignore __nextcloud__ and __sonarr__. These applications will be skipped if they have an update.

> `-t` I set it to 600 seconds, this means the script will wait 600 seconds for the application to become ACTIVE before timing out and rolling back to the previous version since `-r` is used. 

> `--ignore-img` Will not update the application if it is only a container image update

> `-r` Will rollback applications if they fail to deploy within the timeout, after updating.

> `-s` will just sync the repositories, ensuring you are downloading the latest updates.

> `-p` Prune docker images.

> `-u` update applications as long as the major version has absolutely no change, if it does have a change it will ask the user to update manually.
>> The `5` after the `-u` means up to 5 applications will be updating and monitored at one time

> `--self-update` Will update the script prior to running anything else.

<br >

#### My Personal Cron Job
```
heavyscript --self-update -b 10 -rsp -u 10
```

<br >
<br>

## Other Utilities
> All of these can ALSO be accessed with the HeavyScript menu, that you can access simply by not providing an argument `heavyscript`

| Flag            | Description                                                                                  |
|-----------------|----------------------------------------------------------------------------------------------|
| --mount         | Initiates mounting feature, choose between unmounting and mounting PVC data                  |
| --restore       | Opens a menu to restore a HeavyScript backup that was taken on your ix-applications dataset |
| --delete-backup | Opens a menu to delete backups on your system                                                |
| --dns           | list all of your applications DNS names and their web ports                                  |
| --cmd           | Open a shell for one of your applications                                                    |
| --logs          | Open logs for one of your applications                                                       |


### Examples
#### Mounting PVC Data

```
heavyscript --mount
```

#### Restoring ix-applications dataset

```
heavyscript --restore
```

#### Deleting Backups

```
heavyscript --delete-backup
```

#### List All DNS Names

```
heavyscript --dns
```

#### Open a Containers Shell

```
heavyscript --cmd
```

<br>
<br>


## How to Install

### One Line Install
```
curl -s https://raw.githubusercontent.com/Heavybullets8/heavy_script/main/functions/deploy.sh | bash 
```

From here, you can just run HeavyScript with `heavyscript -ARGUMENTS`

> Note: `chmod +x` is already applied to the script, with the one line install, self updates will also chmod the required files.

<br>

## How to Update 

### Built-In Option (Recommended)

```
heavyscript --self-update -b 10 -supr
```
> The important argument here is the `--self-update`, you can still use all of your same arguments with this option.
>> `--self-update` will place users on the latest tag, as well as showing the changelog when new releases come out. So this is the preferred method. Not using this method, will instead place the user on `main`, where the changes are tested, but not as rigerously as they are on the releases.

<br >

### Manually

#### Open a Terminal 

**Change Directory to your heavy_script folder**
```
cd /mnt/speed/scripts/heavy_script
```

Or, if you used the one click install.

```
cd /root/heavy_script
```

**git pull**
```
git pull
```
> This is not recommended because the changes to main are not tested as much as the changes that are pushed to releases are tested, think of this method of updating as being in development. 

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
| `Command`              	| `heavyscript --self-update -b 10 -rsp -u 10` 	| This is the command you will be running on your schedule  I personally use:  `heavyscript --self-update -b 10 -rsp -u 10` 	|
| `Run As User`          	| `root`                                                                                                            	| Running the script as `root` is REQUIRED. You cannot access all of the kubernetes functions without this user.                                                                                 	|
| `Schedule`             	| Up to you, I run mine everyday at `0400`                                                                          	| Again up to you                                                                                                                                                                                	|
| `Hide Standard Output` 	| `False` or Unticked                                                                                               	| I like to receive an email report of how the script ran, what apps updated etc.                                                                                                                	|
| `Hide Standard Error`  	| `False`  or Unticked                                                                                              	| I want to see any errors that occur                                                                                                                                                            	|
| `Enabled`              	| `True` or Ticked                                                                                                  	| This will Enable the script to run on your schedule                                                                                                                                            	|



<br >
<br >

### Additional Information

#### Verbose vs Non-Verbose 
-  Verbose used `heavyscript -b 5 -Srupv`
- Non-Verbose used `heavyscript -b 5 -Srup`

| Verbose 	| Non-Verbose 	|
|---------	|-------------	|
|  ![image](https://user-images.githubusercontent.com/20793231/167971188-07f71d02-8da3-4e0c-b9a0-cd26e7f63613.png) |   ![image](https://user-images.githubusercontent.com/20793231/167972033-dc8d4ab4-4fb2-4c8a-b7dc-b9311ae55cf8.png) |
       

