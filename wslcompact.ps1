#  WSL compact, v2.2023.01.29
# 
#  (C) 2023 Oscar Lopez. 
#  For more information visit: https://github.com/okibcn/wslcompact
# 

$sf = 1.05
$info = $false
$help = $false
$target_distros = foreach ($arg in $args) {
    if ($arg -notmatch '-[hi]') { 
        $arg
    }
    else { 
        $info = $info -or ("Ii" -match $arg[1])
        $help = $help -or ("Hh" -match $arg[1])
    }
}
Write-Host " WSL compact, v2.2023.01.29
 (C) 2023 Oscar Lopez. 
 wslcompact -h for help. For more information visit: https://github.com/okibcn/wslcompact
 "

if ($help) {
    Write-Host "
    Usage: wslcompact [OPTION] [DISTROS]

    Compacts the image file of the DISTROS. If no distro is provided it will compact all the images.
    You can get a list of your installed distros with the command: wsl -l
    NOTE: WSL will be shutdown for compacting the images.

    Options:
        -i   runs in info mode, providing data and estimation without compacting.
        -h   prints this help

    Examples: 
        wslcompact
        wslcompact -i
        wslcompact Ubuntu Kali

    "
    exit 0
}
$tmp_folder = "$Env:TEMP\wslcompact"
$freedisk = (Get-PSDrive $env:TEMP[0]).free
mkdir "$tmp_folder" -ErrorAction SilentlyContinue | Out-Null
remove-item "$tmp_folder/*" -Recurse -Force 
Get-ChildItem HKCU:\Software\Microsoft\Windows\CurrentVersion\Lxss\`{* | ForEach-Object {
    $wsl_ = Get-ItemProperty $_.PSPath
    $wsl_distro = $wsl_.DistributionName
    $wsl_path = if ($wsl_.BasePath.StartsWith('\\')) { $wsl_.BasePath.Substring(4) } else { $wsl_.BasePath }
    if ( !$target_distros -or ($wsl_distro -in $target_distros) ) {
        # The wsl_distro is marked for processing
        $size1 = (Get-Item -Path "$wsl_path\ext4.vhdx").Length / 1MB
        $estimated = ((wsl -d "$wsl_distro" -e df /) | select-string " +\d+ +(\d+)").Matches[0].Groups[1].Value
        $estimated = [long]$estimated * 1024
        Write-Host " Processing: $wsl_distro distro"
        Write-Host " Image file: $wsl_path\ext4.vhdx"
        Write-Host " Image size: $size1 MB"
        Write-Host " Estimating target size..." -NoNewLine
        Write-Host "$([long]($estimated / 1MB * ((($sf - 1) / 2) + 1))) ± $([long]($estimated / 1MB * ($sf - 1) / 2)) MB"
        if (($estimated * $sf) -lt $freedisk) {
             # There is enough free space in the TEMP drive
            if (!($info))
            {   # we are not in info mode.
                Write-Host " "  -NoNewLine
                wsl --shutdown
                cmd /c "wsl --export ""$wsl_distro"" - | wsl --import wslclean ""$tmp_folder"" -" 
                wsl --shutdown
                Move-Item "$tmp_folder/ext4.vhdx" "$wsl_path" -Force
                wsl --unregister wslclean | Out-Null
                $size2 = (Get-Item -Path "$wsl_path\ext4.vhdx").Length / 1MB
                Write-Host " Compacted from $size1 MB to $size2 MB`n"
            }        
        }
        else {
            # There isn't enough free space in the TEMP drive
            write-Host " WARNING: there isn't enough free space in temp drive"(Get-PSDrive $env:TEMP[0])"to process $wsl_distro."
            write-Host "          There are only"([long]($freedisk / 1MB))"MB available."
            write-Host ""
            write-Host " Please, change the TEMP folder to a drive with at least"([long]($estimated * $sf / 1MB))"MB of free space."
            write-Host " You cand do it by typing `$env:TEMP=`"Z:/your/new/temp/folder`" before using wslcompact.`n"
        }
    }
}
Remove-Item -Recurse -Force "$tmp_folder"
write-Host ""
