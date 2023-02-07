# HeavyScript

## Website 

[HeavySetup - Further Explanation](https://heavysetup.info/scripts/heavyscript/about/)

## Table of contents:
* [The Menu](#the-menu)
* [Arguments](#arguments)
   * [Update Specific](#update-specific)
   * [General](#general)
   * [Utilities](#utilities)
   * [Miscellaneous](#Miscellaneous)
* [How to Install](#how-to-install)
* [How to Update](#how-to-update)
* [Cron Jobs](#cron-jobs)
* [Additional Information](#additional-information)

<br>

## The Menu

![image](https://user-images.githubusercontent.com/20793231/217160027-8112a76f-13f3-4aaa-8a64-4a84f1a68ed6.png)
> Access this with `heavyscript`

<br >
<br >

## Arguments

### Update Specific
| Flag         | Example                | Parameter        | Description                                                                                                                                                                |
|--------------|------------------------|------------------|----------------------------------------------------------------------------------------------------------------------------------------------------------------------------|
| -U           | -U <br>-U 5            | Optional Integer | Update applications, ignoring major version changes<br>_Optionally, you can supply a number after the argument to update multiple applications at once_                    |
| -u           | -u<br>-u 5             | Optional Integer | Update applications, do NOT update if there was a major version change<br>_Optionally, you can supply a number after the argument to update multiple applications at once_ |
| -S           | -S                     |                  | Shutdown the application prior to updating it                                                                                                                              |
| -i           | -i nextcloud -i sonarr | String           | Exclude an application from updates<br>_List one application after another as shown in the example_                                                                        |
| -r           | -r                     |                  | Monitors applications after they update<br>If the app does not become "ACTIVE" after the timeout, rollback the application.                                                |
| -t           | -t 400                 | Integer          | Time in seconds that HeavyScript will wait for an application to no longer be deploying before declaring failure<br>Default: 500                                           |
| --ignore-img | --ignore-img           |                  | Ignore container image updates                                                                                                                                             |

<br >

### General
> These options can be used in conjunction with the update options above

> Alternatively, use these options individually or combined with other arguments

| Flag          | Example | Parameter | Description                                                                       |
|---------------|---------|-----------|-----------------------------------------------------------------------------------|
| -b            | -b 14   | Integer   | Backup your ix-applications dataset prior to updating, up to the number specified |
| -s            | -s      |           | Synchronize catalog information                                                   |
| -p            | -p      |           | Remove unused or old Docker images                                                |
| --self-update | --self-update      |           | Update HeavyScript prior to executing other commands                              |

<br >

### Utilities
> All of these can ALSO be accessed with the HeavyScript menu, that you can access simply by not providing an argument `heavyscript`

| Flag            | Description                                                                                  |
|-----------------|----------------------------------------------------------------------------------------------|
| --mount         | Initiates mounting feature, choose between unmounting and mounting PVC data                  |
| --restore       | Opens a menu to restore a HeavyScript backup that was taken on your ix-applications dataset  |
| --delete-backup | Opens a menu to delete backups on your system                                                |
| --dns           | List all of your applications DNS names and their web ports                                  |
| --cmd           | Open a shell for one of your applications                                                    |
| --logs          | Open logs for one of your applications                                                       |
| --stop-app      | Opens menu to Stop one of your applications                                                  |
| --restart-app   | Opens menu to Restart one of your applications                                               |
| --delete-app    | Opens menu to Delete one of your applications                                                |


<br>

### Miscellaneous
| Flag | Example | Description             |
|------|---------|-------------------------|
| -h   | -h      | Displays help message   |
| -v   | -v      | Display detailed output |


<br>
<br>


## How to Install

### One Line Install
```
curl -s https://raw.githubusercontent.com/Heavybullets8/heavy_script/main/functions/deploy.sh | bash && source "$HOME/.bashrc" 2>/dev/null && source "$HOME/.zshrc" 2>/dev/null
```

This will:
- Download HeavyScript, then place you on the latest release
- Place HeavyScript in `/root`
- Make HeavyScript executable
- Allow you to run HeavyScript from any directory with `heavyscript`
 > This does not include Cron Jobs, see the Cron section for more information.

From here, you can just run HeavyScript with `heavyscript -ARGUMENTS`

<br>
<br>
 
## How to Update 

```
heavyscript --self-update -b 10 -supr
```

--self-update will:
- Update HeavyScript to the latest release, no matter if you're on a branch or tag
- Lets you use any other arguments you want

<br >
<br >

## Cron Jobs

### How to Create a Cron Job

1. TrueNAS SCALE GUI
2. System Settings
3. Advanced
4. Cron Jobs
   1. Click Add

![image](https://user-images.githubusercontent.com/20793231/215238304-0ef18468-acc9-417a-8dc3-cbb5a88a36d2.png)


- Command: `bash /root/heavy_script/heavy_script.sh --self-update -b 10 -rsp -u 10`
   > The `bash`, as well as the full path to the script is required for cron jobs to work properly.
- Run as: root
   > Running as root is required for the script to work properly.
- Schedule: I run mine daily at 4:00 AM
- Hide Standard Output: Unchecked
- Hide Standard Error: Unchecked
   > Keep these both unchecked so you can recive an email.


<br >

### My Personal Cron Job

```
bash /root/heavy_script/heavy_script.sh --self-update -b 10 -rsp -u 10
```


<br >
<br >

### Additional Information

#### Verbose vs Non-Verbose 
-  Verbose used `heavyscript -b 5 -Srupv`
- Non-Verbose used `heavyscript -b 5 -Srup`

| Verbose 	| Non-Verbose 	|
|---------	|-------------	|
|  ![image](https://user-images.githubusercontent.com/20793231/167971188-07f71d02-8da3-4e0c-b9a0-cd26e7f63613.png) |   ![image](https://user-images.githubusercontent.com/20793231/167972033-dc8d4ab4-4fb2-4c8a-b7dc-b9311ae55cf8.png) |
       

