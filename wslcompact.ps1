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
