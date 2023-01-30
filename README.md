# WSL Compact

Compacts the size of the WSL images by removing unused empty space.


## FEATURES

It compacts the vhdx virtual images of the WSL2 distros. It ensures the minimum size possible. The program provides the following info for each installed distro:
- Name
- image file location
- Current size of the image file
- Estimated compacted size

By default it will perform in compact mode. and if no distro is specified, it will compact all the installed images sequentially.


## USAGE

The usage is straightforward. Calling `wslcompact` without arguments compacts all the WSL images. Or you can compact a single one passing its name as an argument, for instance `wslcompact Ubuntu`. It ensures a minimal size and you end up with contiguous files for faster access in old HD-based systems. The list of names of the installed distros is accessible by typing `wsl -l` in any powershell terminal. with the `-i` info mode, it wont compact the images providing only the info.

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


## INSTALLATION

TBD