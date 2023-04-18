# HeavyScript

## Contact

If you have questions or would like to contribute, I have a sub discord category hosted on the Truecharts Discord.

[https://discord.gg/tVsPTHWTtr](https://discord.gg/tVsPTHWTtr)

## Website 

[HeavySetup - Further Explanation](https://heavysetup.info/scripts/heavyscript/about/)

## Table of contents:
<details>
  <summary>Click to expand</summary>

* [The Menu](#the-menu)
* [Arguments](#arguments)
   * [App](#app)
   * [Backup](#backup)
   * [DNS](#dns)
   * [Git](#git)
   * [Pod](#pod)
   * [PVC](#pvc)
   * [Self-Update](#self-update)
   * [Update](#update)
* [How to Install](#how-to-install)
* [How to Update](#how-to-update)
* [Configuration File](#configuration-file)
* [Cron Jobs](#cron-jobs)
</details>


<br>

___

## The Menu

![image](https://user-images.githubusercontent.com/20793231/226242159-f4248e0c-649a-47f1-9ee3-293165f4af3b.png)
> Access this with `heavyscript`

<br>

___

## Arguments

### App
> heavyscript app [Flag]

| Flag           | Example                                  | Parameter                 | Description                               |
|----------------|------------------------------------------|---------------------------|-------------------------------------------|
| -s<br>--start  | -s<br>--start                            | [Optional: app name]      | Start an application.                     |
| -x<br>--stop   | -x<br>--stop                             | [Optional: app name]      | Stop an application.                      |
| -r<br>--restart| -r<br>--restart                          | [Optional: app name]      | Restart an application.                   |
| -d<br>--delete | -d<br>--delete                           | [Optional: app name]      | Delete an application.                    |

<br>

### Backup
> heavyscript backup [Flag]

| Flag                           | Example                                  | Parameter        | Description                             |
|--------------------------------|------------------------------------------|------------------|-----------------------------------------|
| -c [number]<br>--create [number]| -c 15<br>--create 15                     | Integer          | Create a backup with the specified retention number. |
| -r<br>--restore                | -r<br>--restore                          |                  | Restore a backup.                       |
| -d<br>--delete                 | -d<br>--delete                           |                  | Delete a backup.                        |

<br>

### DNS
> heavyscript dns [Optional Flag]

| Flag                       | Example                                  | Description                             |
|----------------------------|------------------------------------------|-----------------------------------------|
| -a<br>--all                | -a<br>--all                              | Display all DNS information.            |

<br>

### Git
> heavyscript git [Flag]

| Flag                       | Example                                  | Description                                   |
|----------------------------|------------------------------------------|-----------------------------------------------|
| -b<br>--branch             | -b<br>--branch                           | Choose a branch or tag for HeavyScript to use |
| -g<br>--global             | -g<br>--global                           | Add the script to the global path.            |

<br>

### Pod
> heavyscript pod [Flag]

| Flag                       | Example                                  | Description                                  |
|----------------------------|------------------------------------------|----------------------------------------------|
| -l<br>--logs               | -l<br>--logs                             | Display container logs.                      |
| -s<br>--shell              | -s<br>--shell                            | Open a shell for the container.              |

<br>

### PVC
> heavyscript pvc [Optional Flag]

| Flag                       | Example                                  | Description                                  |
|----------------------------|------------------------------------------|----------------------------------------------|
| -m<br>--mount              | -m<br>--mount                            | Open a menu to mount PVCs.                   |
| -u<br>--unmount            | -u<br>--unmount                          | Unmount all mounted PVCs.                    |

<br>

### Self-Update
> heavyscript self-update

| Flag       | Example            | Description                               |
|------------|--------------------|-------------------------------------------|
| --major    | --major            | Includes major updates when self-updating |



<br>

### Update
> heavyscript update [Flags]

| Flag                   | Example                                  | Parameter        | Description                                                                                                                                                                |
|------------------------|------------------------------------------|------------------|----------------------------------------------------------------------------------------------------------------------------------------------------------------------------|
| -a<br>--include-major    | -a<br>--include-major                    |                  | Update the application even if it is a major version update                                                                                                                |
| -b<br>--backup           | -b 14<br>--backup 14                     | Integer          | Take a backup, and set the number of backups to keep                                                                                                                       |
| -c<br>--concurrent       | -c 5<br>--concurrent 5                   | Integer          | How many applications to concurrently update (default: 1)                                                                                                                  |
| -i<br>--ignore           | -i nextcloud -i sonarr<br>--ignore nextcloud --ignore sonarr | String           | Ignore updating the specified application                                                                                                                                  |
| -I<br>--ignore-img       | -I<br>--ignore-img                       |                  | Ignore container image updates                                                                                                                                             |
| -p<br>--prune            | -p<br>--prune                            |                  | Prune unused images after the update                                                                                                                                       |
| -r<br>--rollback         | -r<br>--rollback                         |                  | Roll back to the previous version if update failure                                                                                                                         |
| -s<br>--sync             | -s<br>--sync                             |                  | Sync the catalog prior to updating applications                                                                                                                             |
| -x<br>--stop             | -x<br>--stop                             |                  | Stop the application prior to updating                                                                                                                                      |
| -t<br>--timeout          | -t 500<br>--timeout 500                  | Integer          | Set the timeout for the update process in seconds (default: 500)                                                                                                           |
| -U<br>--self-update      | -U<br>--self-update                      |                  | Update HeavyScript itself prior to updating                                                                                                                                 |
| -v<br>--verbose          | -v<br>--verbose                          |                  | Display verbose output                                                                                                                                                      |


<br>

___


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

___
 
## How to Update

### While Updating

```bash
heavyscript update --self-update [OPTIONS]
```

### Direct

```bash
heavyscript self-update
```

self-update will update HeavyScript to the latest release, regardless of the branch or tag you're on, and allows you to use any other arguments.

<br>

___

## Configuration File

### Purpose

The configuration file is generated the first time the script is run. You can edit it using nano:

```bash
nano ~/heavy_script/config.ini
```

Modifications in the config file will become the script's defaults. 

For example, if you set sync to true under the [UPDATE] section, running `heavyscript update` will sync the catalog without specifying `--sync` or `-s` in the CLI.

<br>

### Disabling the Configuration

To disable the configuration for a specific run of the script, use:

```bash
heavyscript --no-config
```

This will ignore the configuration file for that run.

<br>

___

## Cron Jobs

### How to Create a Cron Job

1. TrueNAS SCALE GUI
2. System Settings
3. Advanced
4. Cron Jobs
   1. Click Add

![image](https://user-images.githubusercontent.com/20793231/229404447-6836ff1f-ba28-439e-99fe-745371f0f24c.png)


- Command: `bash /root/heavy_script/heavy_script.sh update`
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
bash /root/heavy_script/heavy_script.sh update --backup 14 --concurrent 10 --prune --rollback --sync --self-update
```


<br >
<br >

