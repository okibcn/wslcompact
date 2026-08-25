<div align="center">

# **WSLCOMPACT**

[![Release](https://github.com/okibcn/wslcompact/actions/workflows/Release.yml/badge.svg)](https://github.com/okibcn/wslcompact/actions/workflows/Release.yml)
[![Version](https://img.shields.io/github/v/release/okibcn/wslcompact)](https://github.com/okibcn/wslcompact/releases/latest) [![Github All Releases](https://img.shields.io/github/downloads/okibcn/wslcompact/total.svg)](https://github.com/okibcn/wslcompact/blob/main/README.md#installation) [![License](https://img.shields.io/badge/license-GPLv3-blue.svg)](./LICENSE)


Safely compacts the size of the ever-growing WSL vhdx images.

(Do you like this utility? give it a ⭐ and share it)

</div></br></br>

## FEATURES

The Windows Subsystem for Linux (WSL) uses VHDX image files to store the ext4 filesystem, but it lacks an effective way to shrink the image when the files are removed. This utility doesn't require elevated credentials,compacting the VHDX virtual drives of the WSL2 distros, and achieving the minimum possible size. By default it will perform in info mode, no action on images, providing the following information for all the distros installed:
- Distro name.
- Image file location.
- Current size of the image file.
- Estimated compacted size.
- Estimated processing time.

If no distro is specified, it will target all the installed images sequentially. It operates in safe mode during the compact process, preventing any unwanted side effect in case of failure. This is a typical use case: Compacting Ubuntu image with confirmation:
```
PS> wslcompact -c Ubuntu
 WslCompact v8.7 2023.03.01
 (C) 2023 Oscar Lopez
 wslcompact -h for help. For more information visit: https://github.com/okibcn/wslcompact
 NOTE: measuring used space briefly starts each distro VM. Sessions elsewhere are left untouched.

Distro name: Ubuntu
Image file: C:\Users\Oki\WSL\Ubuntu\ext4.vhdx
Current size: 12.6 GB
Estimated new size: 10.2 GB (range: 10.2 GB to 10.8 GB)
 The estimated process time using an SSD is about 3 minutes.
 NOTE: You can safely cancel at any time by pressing Ctrl-C

 New Image compacted from 12.6 GB to 10.2 GB
 Do you want to apply changes and use the new image (y/N): y
 Image replaced for distro: Ubuntu
 Previous image kept at C:\Users\Oki\WSL\Ubuntu\ext4.vhdx.bak -- verify the distro boots, then delete it or let the next run prune it.

Distro Before After   Saved    Status
------ ------ ------- -------- -------
Ubuntu 12.6 GB 10.2 GB 2,368 MB Replaced

 Total saved: 2,368 MB in 02:15
```

A progress bar tracks the export/import.


## INSTALLATION

Before installing wslcompact, ensure your WSL installation is up to date. You can do that by typing `wsl --update` in PowerShell. WslCompact requires at least WSL version 1.0.0.

There are three ways to install WslCompact, choose your favorite. A winget submission is planned, but it is not yet live:

### OPTION 1: From PSGallery (pending publication)

Install the module from the [PowerShell Gallery](https://www.powershellgallery.com/packages/WslCompact) (pending publication):
```pwsh
Install-Module WslCompact -Scope CurrentUser
# accept the PSGallery trust prompt once, or pre-trust:
Set-PSRepository PSGallery -InstallationPolicy Trusted

Update-Module WslCompact   # later updates
```

#### UNINSTALLATION

To remove the utility, close all your PowerShell instances, open a fresh one and type:
```pwsh
$base = Join-Path ([Environment]::GetFolderPath('MyDocuments')) $(if ($PSVersionTable.PSVersion.Major -ge 6) { 'PowerShell\Modules' } else { 'WindowsPowerShell\Modules' })
Remove-Item (Join-Path $base 'WslCompact') -Recurse -Force
```

If you use both PowerShell editions, run it again in the other edition.

### OPTION 2: With the setup script

It requires a special setting to run a remote script. If you have set it in the past, then you don't need it anymore. If you are not sure, in PowerShell just type:
```pwsh
Set-ExecutionPolicy RemoteSigned -Scope CurrentUser
```
To install or update the utility, close all your PowerShell instances, open a fresh one and type:
```pwsh
iwr -useb https://raw.githubusercontent.com/okibcn/wslcompact/main/setup | iex

# Pinned to v8.7 (manual upgrades only):
iwr -useb https://raw.githubusercontent.com/okibcn/wslcompact/8.7/setup | iex
```

Each release publishes a `.zip.sha256` checksum file; verify downloads with `(Get-FileHash .\WslCompact-v8.7.zip -Algorithm SHA256).Hash` compared against it. The zip also contains `wslcompact.ps1`, a portable entry point: run it with `powershell -ExecutionPolicy Bypass -File .\wslcompact.ps1` (or relax your ExecutionPolicy for local scripts) — plain `.ps1` files are blocked under the default policy.

### OPTION 3: As a Scoop app

If you use **[Scoop package manager](https://scoop.sh/)**, then you can add the wslcompact utility directly from its bucket. Type in PowerShell these two lines:
```pwsh
scoop bucket add .oki https://github.com/okibcn/Bucket
scoop install wslcompact
```
To update the app just type:
```pwsh
scoop update wslcompact
```

#### UNINSTALLATION
To remove the app just type:
```pwsh
scoop uninstall wslcompact
```

## ⚠️ WARNING

Compacting (`-c`) executes `wsl --shutdown`, which **stops every running WSL distribution** — shells, dev servers, and the Docker Desktop backend — even if you targeted a single distro. Save your work first. wslcompact lists the affected distros and asks for confirmation unless `-y` is passed.

## HOW IT COMPARES

Native options exist, each with real tradeoffs. As of Aug 2026 there is no built-in
one-shot shrink command: `wsl --manage --resize` expands only, and sparse VHDs
(`--set-sparse`) are disabled by default since WSL 2.5.6 over data-corruption reports
([release notes](https://github.com/microsoft/WSL/releases/tag/2.5.6),
[#10609](https://github.com/microsoft/WSL/issues/10609),
[#12103](https://github.com/microsoft/WSL/issues/12103)).

| Method | Admin | Safety model | Type | Notes |
|---|---|---|---|---|
| WSLCompact | No | Staged swap via export/import; original kept until you confirm replacement | One-shot | Needs free TEMP space ≈ image size; batch report + batch compact |
| `--set-sparse true` | No | Experimental; gated behind `--allow-unsafe` since 2.5.6 (corruption reports) | Ongoing | Unreliable reclaim; needs discard mount + fstrim; no Win10 |
| diskpart `compact vdisk` | Yes | In-place edit of your only vhdx copy | One-shot | Any edition; `wsl --shutdown` first ([docs](https://learn.microsoft.com/en-us/windows/wsl/disk-space)) |
| Optimize-VHD `-Mode Full` | Yes | In-place | One-shot | Hyper-V module → Pro/Enterprise/Education |

All methods require `wsl --shutdown`. If admin and in-place edits are acceptable,
diskpart works fine. WSLCompact's niche: user-level operation, non-destructive
staged swaps that survive a mid-process failure, and per-distro size reporting
across all installed distros in one run.

## USAGE

After installation, the usage is straightforward:
- Calling `wslcompact` without arguments lists all the WSL images and information. No action on images will be performed.
- You can select specific distros by passing their names as parameters, for instance `wslcompact Ubuntu`. 
- When using the `-c` compact option, wslcompact will modify the images after confirmation.
- There is a special mode for data partitions. `-d` allows the compact of data partitions.

the utility ensures a minimal size and you end up with contiguous files, plausibly faster on old HD-based systems, though this is untested. Should you need the list of names of your distros, it is accessible by typing `wsl -l`. 

```


 Usage: wslcompact [OPTIONS] [DISTROS]

 wslcompact compacts the images of WSL distros by removing unused space.
 If no option is provided, it will default to info mode, without modifying any image.
 If no distro is provided it will process all the installed images.
 NOTE: WSL will be shutdown for compacting the images.

 Options:
  no opt. Provides distro name, path, size, and estimated new size information.
     -c   Compacting mode: process the selected distros compacting the images.
     -y   replaces selected images without asking for confirmation (also skips the shutdown prompt).
     -d   Enable the processing of data images (names ending in '-data'). Default is disabled.
     -v   Prints the version.
     -h   Prints this help

 Examples:
      wslcompact
      wslcompact Ubuntu
      wslcompact -c Ubuntu
      wslcompact -c -d -y Ubuntu Kali

 Long forms -Compact, -Force, -Data, -Help, -Version are accepted. Bundled short
 flags like -cy are not supported. See also: Get-Help WslCompact.
```

For scripting, pass `-PassThru` to receive one object per distro with the properties `Distro`, `Path`, `OldMB`, `NewMB`, `SavedMB`, `Action`, and `Success`. Compact mode also prints an end-of-run summary table.


if your C: drive doesn't have enough temporal free space, the program won't compact that distro. Just change the TEMP folder before calling the function. So, instead of a simple `wslcompact`, just do:
```pwsh
$env:TEMP="Z:\your temp\folder"
wslcompact
```
The new TEMP folder will be active only for that PowerShell terminal session, so no problem at all for the rest of the system and it won't leave garbage.

## SCHEDULING

To run wslcompact unattended, create a weekly scheduled task that imports the module and runs a silent compact:

```pwsh
schtasks /Create /TN "WSL Compact" /SC WEEKLY /D SUN /ST 03:00 /TR "powershell -NoProfile -Command \"Import-Module <path>\WslCompact.psm1; wslcompact -c -y\""
```

Gotchas:
- The task must run as the user who installed the module; the module and the distros live in that user's profile.
- Compacting executes `wsl --shutdown`, killing every running distro including the Docker Desktop backend — schedule it off-hours.
- The TEMP drive needs free space roughly equal to the largest targeted image.
- Execution policy must allow importing the module: `RemoteSigned` at minimum.

## EXAMPLES

A typical operation would be:

```
PS> wslcompact
 WslCompact v8.7 2023.03.01
 (C) 2023 Oscar Lopez
 wslcompact -h for help. For more information visit: https://github.com/okibcn/wslcompact
 NOTE: measuring used space briefly starts each distro VM. Sessions elsewhere are left untouched.

Distro name: Ubuntu
Image file: C:\Users\Oki\WSL\Ubuntu\ext4.vhdx
Current size: 12.6 GB
Estimated new size: 10.2 GB (range: 10.2 GB to 10.8 GB)
 The estimated process time using an SSD is about 3 minutes.

Distro name: Kali
Image file: C:\Users\Oki\WSL\Kali\ext4.vhdx
Current size: 1,579 MB
Estimated new size: 723 MB (range: 723 MB to 759 MB)
 The estimated process time using an SSD is about 1 minute.

Distro name: Arch
Image file: C:\Users\Oki\WSL\Arch\ext4.vhdx
Current size: 1,075 MB
Estimated new size: 860 MB (range: 860 MB to 903 MB)
 The estimated process time using an SSD is about 1 minute.
```

Compacting the Ubuntu image with confirmation:
```
PS> wslcompact -c Ubuntu
 WslCompact v8.7 2023.03.01
 (C) 2023 Oscar Lopez
 wslcompact -h for help. For more information visit: https://github.com/okibcn/wslcompact
 NOTE: measuring used space briefly starts each distro VM. Sessions elsewhere are left untouched.

Distro name: Ubuntu
Image file: C:\Users\Oki\WSL\Ubuntu\ext4.vhdx
Current size: 12.6 GB
Estimated new size: 10.2 GB (range: 10.2 GB to 10.8 GB)
 The estimated process time using an SSD is about 3 minutes.
 NOTE: You can safely cancel at any time by pressing Ctrl-C

 New Image compacted from 12.6 GB to 10.2 GB
 Do you want to apply changes and use the new image (y/N): y
 Image replaced for distro: Ubuntu
 Previous image kept at C:\Users\Oki\WSL\Ubuntu\ext4.vhdx.bak -- verify the distro boots, then delete it or let the next run prune it.

Distro Before After   Saved    Status
------ ------ ------- -------- -------
Ubuntu 12.6 GB 10.2 GB 2,368 MB Replaced

 Total saved: 2,368 MB in 02:15
```

## NOTES

- Info mode measures used space by starting each distro's VM briefly.
- Time estimates assume ~4 GB/min on an SSD; expect slower runs on HDDs.
- Requires WSL >= 1.0.0: older builds lack `wsl --version` and `WSL_UTF8` support.
- Interrupted runs are safe — the original image stays untouched until you confirm the replacement. Rerunning restarts the current distro's compact from scratch (there is no resume).
- After a successful replacement, the previous image remains next to the new one as `ext4.vhdx.bak` until you delete it, or until it is pruned by the next successful compact of that distro.

## LICENSE

Copyright (c) 2023 Oscar Lopez. Released under the [GPL-3.0](./LICENSE).

Unless stated otherwise, contributions are provided under GPL-3.0.

