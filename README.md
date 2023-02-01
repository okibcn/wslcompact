# WSLCOMPACT

Compacts the size of the WSL images by removing unused empty space.

(Do you like this utility? give it a ⭐)


## FEATURES

The Windows Subsystem for Linux (WSL) uses VHDX image files to store the ext4 filesystem, but it lacks an effective way to shrink the image when the files are removed. This utility compacts the vhdx virtual images of the WSL2 distros. It achieves the minimum possible size. The program provides the following info for each installed distro:
- Distro's name.
- image file location.
- Current size of the image file.
- Estimated compacted size.

By default it will perform in info mode, no action on images. If no distro is specified, it will target all the installed images sequentially. It operates in safe mode during the compact process, preventing any unwanted side effect in case of failure.


## INSTALLATION

The easier way to install wslcompact is by using **[Scoop package manager](https://scoop.sh/)**.

1. If it is not yet installed in your system, Install Scoop by opening a PowerShell terminal (version 5.1 or later) and running in powershell:
```pwsh
Set-ExecutionPolicy RemoteSigned -Scope CurrentUser # Optional: Needed to run a remote script the first time
irm get.scoop.sh | iex
```
2. Add the wslcompact utility directly from its bucket:
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

The usage is straightforward: 
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
 WSL compact, v4.2023.01.31
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
 WSL compact, v4.2023.01.31
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

