# WSLCOMPACT

Compacts the size of the WSL images by removing unused empty space.


## FEATURES

The Windows Subsystem for Linux (WSL) uses VHDX image files to store the ext4 filesystem, but it lacks an effective way to shrink the image when the files are removed. This utility compacts the vhdx virtual images of the WSL2 distros. It achieves the minimum possible size. The program provides the following info for each installed distro:
- Name
- image file location
- Current size of the image file
- Estimated compacted size

By default it will perform in compact mode. and if no distro is specified, it will compact all the installed images sequentially providing also the info about the resulting compacted size.


## INSTALLATION

The easier way to install nano is by using **[Scoop package manager](https://scoop.sh/)**.

1. If it is not yet installed in your system, Install Scoop by opening a PowerShell terminal (version 5.1 or later) and running in powershell:
```pwsh
> Set-ExecutionPolicy RemoteSigned -Scope CurrentUser # Optional: Needed to run a remote script the first time
> irm get.scoop.sh | iex
```
2. Add the wslcompact utility directly from its bucket:
```pwsh
> scoop bucket add .oki https://github.com/okibcn/Bucket
> scoop install wslcompact
```
To update the app just type:
```pwsh
> scoop update wslcompact
```
To remove the app just type:
```pwsh
> scoop uninstall wslcompact
```

## USAGE

The usage is straightforward: 
- Calling `wslcompact` without arguments compacts all the WSL images. 
- You can compact specific distros by passing their names as parameters, for instance `wslcompact Ubuntu`. 
- When using the `-i` info mode option, wslcompact won't modify the images, providing only the info.

It ensures a minimal size and you end up with contiguous files for faster access in old HD-based systems. Should you need the list of names of your distros, it is accessible by typing `wsl -l`. 

    Usage: wslcompact [OPTION] [DISTROS]

    compacts the image file of the DISTROS. If no distro is provided it will compact all the images.

    Options:
        -i   run in info mode, providing data without compacting.
        -h   prints this help

    Examples: 
        wslcompact
        wslcompact -i
        wslcompact Ubuntu Kali


if your C: drive doesn't have enough temporal free space, the program won't compact that distro. Just change the TEMP folder before calling the function. So, instead of a simple `wslcompact`, just do:
```pwsh
$env:TEMP="Z:\your temp\folder"
wslcompact
```
The new TEMP folder will be active only for that PowerShell terminal session, so no problem at all for the rest of the system and it won't leave garbage.
