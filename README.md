# HeavyScript

# Archived Repository Notice

## HeavyScript is Archived

Due to the upcoming update for TrueNAS SCALE ([link to update](https://forums.truenas.com/t/the-future-of-electric-eel-and-apps/5409)), where they will be completely removing k3s and replacing it with Docker Compose, I have decided to archive this repository. Since I do not want to use Docker Compose, I will not be supporting it. The tools that HeavyScript offers will all be deprecated by this release due to that change, as the tools are designed for TrueNAS SCALE's k3s implementation, not Docker.

Instead, I will be switching over to TalosOS, and users should watch the TrueCharts Discord channel for migration notices.

It is also worth noting that TrueCharts has archived and completely removed their charts from TrueNAS SCALE as well, as seen here: [TrueCharts Catalog](https://github.com/truecharts/catalog).

TrueCharts' comments on the situation can be seen here: [TrueCharts Deprecation News](https://truecharts.org/news/scale-deprecation/).

## Personal Note

Developing HeavyScript was my first project and the most fun I've had with coding. Amassing 380+ stars throughout the years is nothing I ever dreamed of when I started the project, and I am sad to see it go.

Thank you to everyone who has supported and used HeavyScript!

Best regards,  
Heavybullets8


## Contact

If you have questions or would like to contribute, I have a sub discord category hosted on the Truecharts Discord.

[https://discord.gg/tVsPTHWTtr](https://discord.gg/tVsPTHWTtr)

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
   * [Sync](#sync)
   * [Update](#update)
* [How to Install](#how-to-install)
* [How to Update](#how-to-update)
* [Configuration File](#configuration-file)
* [Cron Jobs](#cron-jobs)
</details>


<br>

___

## The Menu

![image](https://github.com/Heavybullets8/heavy_script/assets/20793231/8587a732-ae4d-4ab1-b776-641c1ded0193)

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
> heavyscript dns [Optional App Name(s)]

Pass an optional app name to display DNS information for that specific app.

If no app name is provided, it will show internal DNS addresses for all services.

Example:
```sh
heavscript dns sonarr radarr nextcloud
```

<br >

### Enable
> heavyscript enable [Flag]


| Flag          | Example                               | Description                             |
|---------------|---------------------------------------|-----------------------------------------|
| --api         | --api                                 | Enables external access to the Kubernetes API server. |
| --apt         | --apt                                 | Enable apt, apt-get, and apt-key. |
| --helm        | --helm                                | Enable helm commands. |


<br >

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

### Sync
> heavyscript sync

Syncs the catalog.

<br>

### Update
> heavyscript update [Flags]

| Flag                     | Example                                  | Parameter        | Description                                                                                                                                                                |
|--------------------------|------------------------------------------|------------------|----------------------------------------------------------------------------------------------------------------------------------------------------------------------------|
| -a<br>--include-major    | -a<br>--include-major                    |                  | Update the application even if it is a major version update                                                                                                                |
| -b<br>--backup           | -b 14<br>--backup 14                     | Integer          | Take a backup, and set the number of backups to keep                                                                                                                       |
| -c<br>--concurrent       | -c 5<br>--concurrent 5                   | Integer          | How many applications to concurrently update (default: 1)                                                                                                                  |
| -i<br>--ignore           | -i nextcloud,sonarr -i sonarr<br>--ignore nextcloud --ignore sonarr | String           | Ignore updating the specified application                                                                                                                                  |
| -I<br>--ignore-img       | -I<br>--ignore-img                       |                  | Ignore container image updates                                                                                                                                             |
| -p<br>--prune            | -p<br>--prune                            |                  | Prune unused images after the update                                                                                                                                       |
| -r<br>--rollback         | -r<br>--rollback                         |                  | Roll back to the previous version if update failure                                                                                                                         |
| -s<br>--sync             | -s<br>--sync                             |                  | Sync the catalog prior to updating applications                                                                                                                             |
| -u<br>--update-only      | -u nextcloud,sonarr<br>--update-only nextcloud  | String           | Only update the specified application(s)                                                                                                                                    |
| -x<br>--stop             | -x<br>--stop                             |                  | Stop the application prior to updating (Not recommended)                                                                                                                    |
| -t<br>--timeout          | -t 500<br>--timeout 500                  | Integer          | Set the timeout for the update process in seconds (default: 500)                                                                                                           |
| -U<br>--self-update      | -U<br>--self-update                      |                  | Update HeavyScript itself prior to updating                                                                                                                                 |
| -v<br>--verbose          | -v<br>--verbose                          |                  | Display verbose output


<br>

___


## How to Install

HeavyScript can be installed in two different ways depending on your needs and privileges on the system:

### Option 1: Non-Privileged Install (Regular User)

> This installation method is suitable if you don't have root access or prefer not to install HeavyScript with elevated privileges.

**Installation Command:**
```bash
curl -s https://raw.githubusercontent.com/Heavybullets8/heavy_script/main/functions/deploy.sh | bash && source "$HOME/.bashrc" 2>/dev/null && source "$HOME/.zshrc" 2>/dev/null
```

**What This Does:**
- Downloads and places HeavyScript in your user directory.
- Makes HeavyScript executable.
- Allows you to run HeavyScript from any directory using `heavyscript`.

**Note:** 
- Without root privileges, the script will not create a system-wide symlink in `/usr/local/bin`.
- You might see a warning message indicating the lack of root privileges. You can proceed without root access, but you'll need to run HeavyScript with root privileges at least once to create the system-wide symlink, if required.

### Option 2: Privileged Install (Root or Sudo)

> If you have root access or can use `sudo`, this method will set up HeavyScript for all users on the system.

**Installation Command:**
```bash
curl -s https://raw.githubusercontent.com/Heavybullets8/heavy_script/main/functions/deploy.sh | sudo bash && source "$HOME/.bashrc" 2>/dev/null && source "$HOME/.zshrc" 2>/dev/null
```

**What This Does:**
- Installs HeavyScript with root privileges.
- Creates a system-wide symlink in `/usr/local/bin`, making HeavyScript accessible to all users.
- Downloads and places HeavyScript in the root directory (`/root`).
- Makes HeavyScript executable and accessible system-wide.

**Note:**
- This method requires root access or sudo privileges.
- It's recommended for environments where HeavyScript needs to be accessible to multiple users.

---

### Choosing the Right Option:

- **Non-Privileged Install:** Choose this if you're more concerened with security and want to keep HeavyScript isolated to your user account, at least during the initial setup.
- **Privileged Install:** Choose this if you are less concerened about security and want to make HeavyScript accessible to all users on the system, including the root and sudo user. 

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

To automate tasks using HeavyScript, you can create a cron job. Here's how to set it up in TrueNAS SCALE:

1. Navigate to the TrueNAS SCALE GUI.
2. Go to **System Settings** > **Advanced**.
3. Click on **Cron Jobs**.
4. Click **Add** to create a new cron job.

![image](https://user-images.githubusercontent.com/20793231/229404447-6836ff1f-ba28-439e-99fe-745371f0f24c.png)

### Important Note on the Command Path
The command for the cron job should use the full path to the `heavy_script.sh` file. This path depends on the user who installed HeavyScript. For instance, if you installed HeavyScript as a non-root user, replace `/root` with your home directory path.

> You can find your home directory path by running `echo $HOME` in the terminal.

### Cron Job Settings

- **Command:** Use the full command with the correct path, as shown in the examples above. The `bash` prefix and the full path are required for proper execution.
- **Run as:** Use `root`, the extra permissions are required for most heavyscript functions.
- **Schedule:** Choose the frequency and time for the script to run. For example, daily at 4:00 AM.
- **Hide Standard Output/Error:** Uncheck these options if you wish to receive email notifications about the cron job's output and errors.

### My Personal Cron Job

Here's an example of how I set up my personal cron job:

```
bash /root/heavy_script/heavy_script.sh update --backup 14 --concurrent 10 --prune --rollback --sync --self-update
```

> Remember to adjust the path in the command based on where HeavyScript is installed and the user account used for installation.
