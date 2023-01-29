# wslclean
Compacts the size of the WSL images by removing unused space.


## INSTALL

Just edit the default profile with `notepad $PROFILE` in powershell, and add the following function anywhere:

```powershell
function wslcompact($distro){
  $tmp_folder = "$Env:TEMP\wslcompact"
  mkdir "$tmp_folder" -ErrorAction SilentlyContinue | Out-Null
  Get-ChildItem HKCU:\Software\Microsoft\Windows\CurrentVersion\Lxss\`{* | ForEach-Object {
    $wsl_=Get-ItemProperty $_.PSPath
    $wsl_distro=$wsl_.DistributionName
    $wsl_path=if ($wsl_.BasePath.StartsWith('\\')) {$wsl_.BasePath.Substring(4)} else {$wsl_.BasePath}
    if ( !$distro -or ($distro -eq $wsl_distro) ){
      echo "Creating optimized $wsl_distro image."
      $size1 = (Get-Item -Path "$wsl_path\ext4.vhdx").Length/1MB
      wsl --shutdown
      cmd /c "wsl --export ""$wsl_distro"" - | wsl --import wslclean ""$tmp_folder"" -" 
      wsl --shutdown
      Move-Item "$tmp_folder/ext4.vhdx" "$wsl_path" -Force
      wsl --unregister wslclean | Out-Null
      $size2 = (Get-Item -Path "$wsl_path\ext4.vhdx").Length/1MB
      echo "$wsl_distro image file: $wsl_path\ext4.vhdx"
      echo "Compacted from $size1 MB to $size2 MB"
    }
  }
  Remove-Item -Recurse -Force "$tmp_folder"
}
```

Close the PowerShell terminal and reopen it again to ensure the updated profile is active, or just type `. $PROFILE`.

## USAGE

The usage is straightforward. Calling `wslcompact` without arguments compacts all the WSL images. Or you can compact a single one passing its name as an argument, for instance `wslcompact Ubuntu`. It ensures a minimal size and you end up with contiguous files for faster access in old HD-based systems. The list of names of the installed distros is accessible by typing `wsl -l` in any powershell terminal.

if your C: drive doesn't have enough temporal free space, just change the TEMP folder before calling the function. So, instead of a simple `wslcompact`, just do:
```pwsh
$env:TEMP="Z:\your temp\folder"
wslcompact
```
The new TEMP folder will be active only for that PowerShell terminal session, so no problem at all for the rest of the system and it won't leave garbage.
