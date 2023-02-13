<div align="center">

# **WSLCOMPACT**

[![Release](https://github.com/okibcn/wslcompact/actions/workflows/Release.yml/badge.svg)](https://github.com/okibcn/wslcompact/actions/workflows/Release.yml)
[![Version](https://img.shields.io/github/v/release/okibcn/wslcompact)](https://github.com/okibcn/wslcompact/releases/latest) [![Github All Releases](https://img.shields.io/github/downloads/okibcn/wslcompact/total.svg)](https://github.com/okibcn/wslcompact/blob/main/README.md#installation)


Safely compacts the size of the ever-growing WSL vhdx images.

(Do you like this utility? give it a ⭐)

</div></br></br>

## FEATURES

The Windows Subsystem for Linux (WSL) uses VHDX image files to store the ext4 filesystem, but it lacks an effective way to shrink the image when the files are removed. This utility doesn't require elevated credentials,compacting the VHDX virtual drives of the WSL2 distros, and achieving the minimum possible size. By default it will perform in info mode, no action on images, providing the following information for all the distros installed:
- Distro's name.
- image file location.
- Current size of the image file.
- Estimated compacted size.
- Estimated processing time.

If no distro is specified, it will target all the installed images sequentially. It operates in safe mode during the compact process, preventing any unwanted side effect in case of failure. This is a typical use case: Compacting Ubuntu image with confirmation:
```
PS> wslcompact -c Ubuntu
 WSL compact, v5.0 2023.02.02 (Groundhog edition)
 (C) 2023 Oscar Lopez
 wslcompact -h for help. For more information visit: https://github.com/okibcn/wslcompact

 Distro's name:  Ubuntu
 Image file:     C:\Users\Oki\WSL\Ubuntu\ext4.vhdx
 Current size:   12864 MB
 Estimated size: 7700 ± 188 MB
 The estimated process time using an SSD is about 2 minutes.
 NOTE: You can safely cancel at any time by pressing Ctrl-C
 Import in progress, this may take a few minutes.
The operation completed successfully.
 New Image compacted from 12864 MB to 7728 MB
 Do you want to apply changes and use the new image (y/N): y
 Image replaced for distro: Ubuntu
```


## INSTALLATION

Before installing wslcompact, ensure your WSL installation is up to date. You can do that by typing `wsl --update` in PowerShell. WslCompact requires at least WSL version 1.0.0.

There are two ways to install WslCompact, choose your favorite:

### OPTION 1: As a PowerShell module

It requires a special setting to run a remote script. If you have set it in the past, then you don't need it anymore. If you are not sure, in PowerShell just type:
```pwsh
Set-ExecutionPolicy RemoteSigned -Scope CurrentUser
```
To install or update the utility, close all your PowerShell instances, open a fresh one and type:
```pwsh
iwr -useb https://raw.githubusercontent.com/okibcn/wslcompact/main/setup | iex
```
To remove the utility, close all your PowerShell instances, open a fresh one and type:
```pwsh
Remove-Item "$($env:PSModulePath.split(';')[0])/WslCompact" -Recurse -Force
```

### OPTION 2: As a Scoop app

If you use **[Scoop package manager](https://scoop.sh/)**, then you can add the wslcompact utility directly from its bucket. Type in PowerShell these two lines:
```pwsh
scoop bucket add .oki https://github.com/okibcn/Bucket
scoop install wslcompact
```
To update the app just type:
```pwsh
scoop update wslcompact
```
To remove the app just type:
```pwsh
scoop uninstall wslcompact
```

## USAGE

After installation, the usage is straightforward:
- Calling `wslcompact` without arguments lists all the WSL images and information. No action on images will be performed.
- You can select specific distros by passing their names as parameters, for instance `wslcompact Ubuntu`. 
- When using the `-c` compact option, wslcompact will modify the images after confirmation.
- There is a special mode for data partitions. `-d` allows the compact of data partitions.

the utility ensures a minimal size and you end up with contiguous files for faster access in old HD-based systems. Should you need the list of names of your distros, it is accessible by typing `wsl -l`. 

 ```
    Usage: wslcompact [OPTIONS] [DISTROS]

    wslcompact compacts the images of WSL distros by removing unsused space.
    If no option is provided, it will default to info mode, without modifying any image.
    If no distro is provided it will process all the installed images.
    NOTE: WSL will be shutdown for compacting the images.

    Options:
    no opt. Provides name, image file path, current size, and estimated new size information.
        -c   Compacting mode: process the selected distros compacting the images.
        -y   replaces selected images without asking for confirmation.
        -d   Enable the processing of data images. Default is disabled.
        -h   Prints this help

    Examples:
        wslcompact
        wslcompact -c -d
        wslcompact -c -y Ubuntu Kali
```


if your C: drive doesn't have enough temporal free space, the program won't compact that distro. Just change the TEMP folder before calling the function. So, instead of a simple `wslcompact`, just do:
```pwsh
$env:TEMP="Z:\your temp\folder"
wslcompact
```
The new TEMP folder will be active only for that PowerShell terminal session, so no problem at all for the rest of the system and it won't leave garbage.

## EXAMPLES

A typical operation would be:

```
PS> wslcompact
 WSL compact, v5.0 2023.02.02 (Groundhog edition)
 (C) 2023 Oscar Lopez
 wslcompact -h for help. For more information visit: https://github.com/okibcn/wslcompact

 Distro's name:  Ubuntu
 Image file:     C:\Users\Oki\WSL\Ubuntu\ext4.vhdx
 Current size:   12864 MB
 Estimated size: 7700 ± 188 MB
 The estimated process time using an SSD is about 2 minutes.

 Distro's name:  Kali
 Image file:     C:\Users\Oki\WSL\Kali\ext4.vhdx
 Current size:   1579 MB
 Estimated size: 723 ± 18 MB
 The estimated process time using an SSD is about 1 minutes.

 Distro's name:  Arch
 Image file:     C:\Users\Oki\WSL\Arch\ext4.vhdx
 Current size:   1075 MB
 Estimated size: 860 ± 21 MB
 The estimated process time using an SSD is about 1 minutes.
```

Compacting the Ubuntu image with confirmation:
```
PS> wslcompact -c Ubuntu
 WSL compact, v5.0 2023.02.02 (Groundhog edition)
 (C) 2023 Oscar Lopez
 wslcompact -h for help. For more information visit: https://github.com/okibcn/wslcompact

 Distro's name:  Ubuntu
 Image file:     C:\Users\Oki\WSL\Ubuntu\ext4.vhdx
 Current size:   12864 MB
 Estimated size: 7700 ± 188 MB
 The estimated process time using an SSD is about 2 minutes.
 NOTE: You can safely cancel at any time by pressing Ctrl-C
 Import in progress, this may take a few minutes.
The operation completed successfully.
 New Image compacted from 12864 MB to 7728 MB
 Do you want to apply changes and use the new image (y/N): y
 Image replaced for distro: Ubuntu
```

