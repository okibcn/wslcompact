$sf=1.10
$tmp_folder = "$Env:TEMP\wslcompact"
$freedisk=(Get-PSDrive $env:TEMP[0]).free
mkdir "$tmp_folder" -ErrorAction SilentlyContinue | Out-Null
remove-item "$tmp_folder/*" -Recurse -Force 
Get-ChildItem HKCU:\Software\Microsoft\Windows\CurrentVersion\Lxss\`{* | ForEach-Object {
    $wsl_=Get-ItemProperty $_.PSPath
    $wsl_distro=$wsl_.DistributionName
    $wsl_path=if ($wsl_.BasePath.StartsWith('\\')) {$wsl_.BasePath.Substring(4)} else {$wsl_.BasePath}
    if ( !$distro -or ($distro -eq $wsl_distro) ){
        Write-Host " Processing $wsl_distro image:"
        $size1 = (Get-Item -Path "$wsl_path\ext4.vhdx").Length/1MB
        Write-Host " Current size: $size1 MB"
        Write-Host " Estimating target size..." -NoNewLine
        $estimated=((wsl -d "$wsl_distro" -e df /) | select-string "\d (\d+) \d").Matches[0].Groups[1].Value
        $estimated=[long]$estimated*1024
        Write-Host ([long]($estimated/1MB))"MB ± 10%"
        if (($estimated*$sf) -lt $freedisk){
            wsl --shutdown
            cmd /c "wsl --export ""$wsl_distro"" - | wsl --import wslclean ""$tmp_folder"" -" 
            wsl --shutdown
            Move-Item "$tmp_folder/ext4.vhdx" "$wsl_path" -Force
            wsl --unregister wslclean | Out-Null
            $size2 = (Get-Item -Path "$wsl_path\ext4.vhdx").Length/1MB
            Write-Host " $wsl_distro image file: $wsl_path\ext4.vhdx"
            Write-Host " Compacted from $size1 MB to $size2 MB`n"
        } else {
            write-Host " WARNING: there isn't enough free space in temp drive"(Get-PSDrive $env:TEMP[0])"to process $wsl_distro."
            write-Host "          There are only"([long]($freedisk/1MB))"MB available."
            write-Host ""
            write-Host " Please, change the TEMP folder to a drive with at least"([long]($estimated *$sf/1MB))"MB of free space."
            write-Host " You cand do it by typing `$env:TEMP=`"Z:/your/new/temp/folder`" before using wslcompact.`n`""
        }
    }
}
Remove-Item -Recurse -Force "$tmp_folder"



